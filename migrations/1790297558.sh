# Install FaceTime HD support for existing Intel Macs with the Broadcom 1570 PCIe camera.
# Hardware setup covers fresh installs; this migration covers machines already running Omarchy.

if ! lspci -nn | grep -q '14e4:1570'; then
  exit 0
fi

marker="${OMARCHY_FACETIMEHD_MIGRATION_MARKER:-/var/lib/omarchy/migrations/1790297558}"
modules_conf="${OMARCHY_FACETIMEHD_MODULES_CONF:-/etc/modules-load.d/facetimehd.conf}"

# This repair is machine-wide while migration completion is per-user. Only a
# marker written after the rebuild succeeds prevents another user repeating it.
# A missing marker intentionally retries an interrupted install or rebuild.
[[ ! -e $marker ]] || exit 0

echo "Installing FaceTime HD camera support"
omarchy-pkg-add facetimehd-dkms facetimehd-firmware

printf '%s\n' facetimehd | sudo tee "$modules_conf" >/dev/null
sudo limine-mkinitcpio
sudo modprobe facetimehd 2>/dev/null ||
  echo "Could not load facetimehd now; it is configured to load after reboot." >&2
omarchy-state set reboot-required
sudo install -Dm644 /dev/null "$marker"
