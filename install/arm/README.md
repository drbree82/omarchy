# ARM installer support

`corsola-omarchy-install.sh` provisions the current Omarchy userspace on an
Arch Linux ARM aarch64 Corsola Chromebook. It is intentionally separate from
the x86_64 ISO installer: Corsola boots through the postmarketOS/Velvet
ChromeOS GPT and `vmlinux.kpart` path, so the script must not replace the boot
layout or kernel.

The script installs the ARM Omarchy package repository, the published native
ARM Omarchy applications, the official Omarchy-Neovim package from its source
PKGBUILD, and the current Quattro user/system configuration. It retains the
existing ChromeOS/Depthcharge boot arrangement.

The ARM package repository is an unofficial build channel. Its packages are
architecture-specific native aarch64 builds, not x86 binaries.
