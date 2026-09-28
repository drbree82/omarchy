# Install FaceTime HD support for existing Intel Macs with the Broadcom 1570 PCIe camera.
# Hardware setup covers fresh installs; this migration covers machines already running Omarchy.

if ! lspci -nn | grep -q '14e4:1570'; then
  exit 0
fi

modules_conf=/etc/modules-load.d/facetimehd.conf
if omarchy-pkg-present facetimehd-dkms facetimehd-firmware && [[ -f $modules_conf ]] &&
  grep -Fxq facetimehd "$modules_conf"; then
  exit 0
fi

echo "Installing FaceTime HD camera support"
omarchy-pkg-add facetimehd-dkms facetimehd-firmware

printf '%s\n' facetimehd | sudo tee "$modules_conf" >/dev/null
sudo limine-mkinitcpio
sudo modprobe -r bdc_pci 2>/dev/null || true
sudo modprobe facetimehd 2>/dev/null || true
omarchy-state set reboot-required
