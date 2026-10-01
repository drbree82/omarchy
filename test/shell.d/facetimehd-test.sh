#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

camera_installer="$ROOT/install/hardware/apple/fix-facetimehd.sh"
all="$ROOT/install/hardware/all.sh"
offline_packages="$ROOT/install/omarchy-other.packages"
migration="$ROOT/migrations/1790297558.sh"

 grep -Fq 'apple/fix-facetimehd.sh' "$all" ||
  fail "the FaceTime HD fix runs during hardware setup"
pass "the FaceTime HD fix runs during hardware setup"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
calls="$test_tmp/calls.log"
modules="$test_tmp/modules-load.d"
mkdir -p "$stub_bin"
: >"$calls"

cat >"$stub_bin/lspci" <<'SH'
#!/bin/bash
printf '%s\n' "$LSPCI_OUTPUT"
SH
cat >"$stub_bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
printf 'omarchy-pkg-add\t%s\n' "$*" >>"$TEST_LOG"
SH
cat >"$stub_bin/omarchy-pkg-aur-add" <<'SH'
#!/bin/bash
printf 'omarchy-pkg-aur-add\t%s\n' "$*" >>"$TEST_LOG"
SH
cat >"$stub_bin/modprobe" <<'SH'
#!/bin/bash
printf 'modprobe\t%s\n' "$*" >>"$TEST_LOG"
SH
cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash
exec "$@"
SH
chmod +x "$stub_bin"/*

run_leaf() {
  LSPCI_OUTPUT="$1" \
  TEST_LOG="$calls" \
  OMARCHY_FACETIMEHD_MODULES_DIR="$modules" \
  PATH="$stub_bin:$PATH" \
  bash -euo pipefail "$camera_installer"
}

run_leaf '03:00.0 Network controller [0280]: Broadcom [14e4:43a0]' >/dev/null
[[ ! -e "$modules/facetimehd.conf" ]] || fail "non-camera Broadcom hardware is left alone"
[[ ! -s "$calls" ]] || fail "non-camera hardware does not install camera support"
pass "non-camera Broadcom hardware is left alone"

run_leaf '02:00.0 Multimedia controller [0480]: Broadcom 720p FaceTime HD Camera [14e4:1570]' >/dev/null
[[ -f "$modules/facetimehd.conf" ]] || fail "the FaceTime HD module is enabled at boot"
grep -Fxq facetimehd "$modules/facetimehd.conf" || fail "the module-load entry names facetimehd"
grep -Fq $'omarchy-pkg-add\tfacetimehd-dkms facetimehd-firmware' "$calls" ||
  fail "the driver and firmware packages are installed" "$(cat "$calls")"
grep -Fq $'modprobe\t-r bdc_pci' "$calls" || fail "the conflicting bdc_pci driver is unloaded"
grep -Fq $'modprobe\tfacetimehd' "$calls" || fail "the camera driver is loaded immediately"
pass "Broadcom 1570 installs firmware, DKMS, and module loading"

grep -Fxq facetimehd-dkms "$offline_packages" || fail "the offline package set includes facetimehd-dkms"
grep -Fxq facetimehd-firmware "$offline_packages" || fail "the offline package set includes facetimehd-firmware"
pass "the offline package set includes FaceTime HD packages"

grep -Fq 'omarchy-pkg-add facetimehd-dkms facetimehd-firmware' "$migration" ||
  fail "the existing-install migration installs the packaged driver and firmware"
grep -Fq 'omarchy-state set reboot-required' "$migration" ||
  fail "the existing-install migration requests a reboot"

cat >"$stub_bin/omarchy-pkg-present" <<'SH'
#!/bin/bash
[[ -f $TEST_INSTALLED_MARKER ]]
SH
cat >"$stub_bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
printf 'omarchy-pkg-add\t%s\n' "$*" >>"$TEST_LOG"
touch "$TEST_INSTALLED_MARKER"
SH
cat >"$stub_bin/limine-mkinitcpio" <<'SH'
#!/bin/bash
printf 'limine-mkinitcpio\n' >>"$TEST_LOG"
attempts=$(<"$TEST_REBUILD_ATTEMPTS")
attempts=$((attempts + 1))
printf '%s\n' "$attempts" >"$TEST_REBUILD_ATTEMPTS"
(( attempts > 1 ))
SH
cat >"$stub_bin/omarchy-state" <<'SH'
#!/bin/bash
printf 'omarchy-state\t%s\n' "$*" >>"$TEST_LOG"
SH
cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash
if [[ $1 == tee ]]; then
  cat >"$TEST_MODULES_CONF"
else
  "$@"
fi
SH
chmod +x "$stub_bin"/*

migration_modules="$test_tmp/facetimehd.conf"
installed_marker="$test_tmp/packages-installed"
migration_marker="$test_tmp/migration-complete"
rebuild_attempts="$test_tmp/rebuild-attempts"
printf '0\n' >"$rebuild_attempts"
run_migration() {
  LSPCI_OUTPUT='02:00.0 Multimedia controller [0480]: Broadcom FaceTime HD Camera [14e4:1570]' \
  TEST_LOG="$calls" \
  TEST_INSTALLED_MARKER="$installed_marker" \
  TEST_MODULES_CONF="$migration_modules" \
  TEST_REBUILD_ATTEMPTS="$rebuild_attempts" \
  OMARCHY_FACETIMEHD_MODULES_CONF="$migration_modules" \
  OMARCHY_FACETIMEHD_MIGRATION_MARKER="$migration_marker" \
  PATH="$stub_bin:$PATH" \
  bash -euo pipefail "$migration"
}

run_migration && fail "a failed initramfs rebuild fails the first migration run"
[[ $(<"$rebuild_attempts") == 1 ]] || fail "the first migration run attempts one initramfs rebuild"
! grep -q 'omarchy-state.*reboot-required' "$calls" ||
  fail "a failed rebuild does not mark reboot-required"
pass "a failed initramfs rebuild leaves the migration retryable"

run_migration || fail "the migration retries and succeeds after a failed rebuild"
[[ $(<"$rebuild_attempts") == 2 ]] || fail "the retry performs a second initramfs rebuild"
grep -Fxq facetimehd "$migration_modules" || fail "the migration enables facetimehd at boot"
grep -Fq $'modprobe\t-r bdc_pci' "$calls" || fail "the retry unloads the conflicting driver"
grep -Fq $'modprobe\tfacetimehd' "$calls" || fail "the retry loads the camera driver"
grep -Fq $'omarchy-state\tset reboot-required' "$calls" ||
  fail "the successful retry requests a reboot"
pass "the migration completes driver setup after the successful rebuild"

: >"$calls"
run_migration || fail "the completed migration remains successful"
[[ $(<"$rebuild_attempts") == 2 ]] || fail "the completed migration does not rebuild again"
[[ ! -s $calls ]] || fail "the machine-wide completion marker avoids repeating the migration"
pass "the machine-wide marker prevents redundant successful reruns"
