#!/usr/bin/env bash
set -euo pipefail

# ARM Corsola port of the current Omarchy repository install.
# Keeps the existing ChromeOS/Depthcharge kernel and boot layout intact.

[[ "$(uname -m)" == "aarch64" ]] || { echo "This installer requires aarch64." >&2; exit 1; }

# Fresh Corsola installs use a dedicated, clearly-named ARM desktop account.
# Override both values in an unattended environment; the initial password must
# be changed immediately after first login.
CHROMARCHY_USERNAME="${CHROMARCHY_USERNAME:-chromarchy}"
CHROMARCHY_PASSWORD="${CHROMARCHY_PASSWORD:-chromarchy}"

if [[ ${1:-} != --as-user ]]; then
  if (( EUID == 0 )); then
    if ! id "$CHROMARCHY_USERNAME" >/dev/null 2>&1; then
      useradd --create-home --groups wheel,audio,video,input "$CHROMARCHY_USERNAME"
    fi
    printf '%s:%s\n' "$CHROMARCHY_USERNAME" "$CHROMARCHY_PASSWORD" | chpasswd
    exec sudo -u "$CHROMARCHY_USERNAME" -H -- "$0" --as-user
  elif [[ ${USER:-} != "$CHROMARCHY_USERNAME" ]]; then
    echo "Run as root for a fresh install, or as $CHROMARCHY_USERNAME." >&2
    exit 1
  fi
else
  shift
fi

# The upstream Omarchy package server has no aarch64 channel. This separate
# ARM repository carries unmodified/native ARM builds of Omacalc, Omacut,
# Omawrite, Tensaku, TTFX, and the other Omarchy applications.
if ! grep -q '^\[omarchy-aarch64\]' /etc/pacman.conf; then
  printf '%s\n' '' '[omarchy-aarch64]' 'SigLevel = Optional TrustAll' \
    'Server = https://github.com/omarchy-mac/omarchy-pkgs-aarch64/releases/download/edge' \
    | sudo tee -a /etc/pacman.conf >/dev/null
fi
sudo pacman -Sy --noconfirm

# Packages from Omarchy's current manifest that are useful and available on
# Arch Linux ARM. Boot kernels, SDDM, NVIDIA, and x86-specific packages are
# deliberately excluded: Corsola boots through its existing ChromeOS layout.
sudo pacman -Syu --noconfirm --needed \
  alsa-utils bash-completion bat bluez bluez-tools bluez-utils bolt \
  brightnessctl btop chromium dua-cli eza evince exfatprogs expac fastfetch \
  fcitx5 fcitx5-gtk fcitx5-qt fd ffmpegthumbnailer foot fzf \
  gnome-keyring gnome-themes-extra grim gpu-screen-recorder gst-plugin-pipewire \
  gum gvfs-mtp gvfs-nfs gvfs-smb hyprland hyprland-guiutils hypridle hyprlock \
  hyprpaper hyprpicker hyprsunset imagemagick imv inotify-tools inxi iw jq \
  lazydocker lazygit less man-db mpv mpv-mpris nautilus network-manager-applet \
  networkmanager noto-fonts noto-fonts-cjk noto-fonts-emoji pamixer pipewire \
  pipewire-alsa pipewire-pulse power-profiles-daemon quickshell ripgrep \
  slurp starship swaybg swaync tmux udiskie unzip uwsm waybar webp-pixbuf-loader \
  wireless-regdb wireplumber wl-clipboard woff2-font-awesome wtype xdg-user-dirs \
  xdg-user-dirs-gtk xdg-desktop-portal-gtk xdg-desktop-portal-hyprland yt-dlp zoxide go \
  tree-sitter-cli aether cliamp localsend omacalc omacut omawrite tensaku ttfx \
  ttf-ia-writer tzupdate xdg-terminal-exec hyprland-preview-share-picker-git

mkdir -p "$HOME/src" "$HOME/.local/bin" "$HOME/.config/hypr" "$HOME/.config/omarchy"
if [[ ! -d "$HOME/src/omarchy/.git" ]]; then
  git clone --depth=1 --branch quattro https://github.com/drbree82/omarchy.git "$HOME/src/omarchy"
else
  git -C "$HOME/src/omarchy" pull --ff-only
fi

sudo ln -sfn "$HOME/src/omarchy" /usr/share/omarchy
sudo mkdir -p /usr/local/bin /usr/share/fonts/omarchy
sudo cp -a "$HOME/src/omarchy/default/fonts/omarchy/." /usr/share/fonts/omarchy/
sudo fc-cache -f /usr/share/fonts/omarchy >/dev/null 2>&1 || true

for helper in "$HOME"/src/omarchy/bin/omarchy-*; do
  [[ -f "$helper" ]] || continue
  ln -sf "$helper" "$HOME/.local/bin/$(basename "$helper")"
  sudo ln -sf "$helper" "/usr/local/bin/$(basename "$helper")"
done

# Use the repository's real Lua configuration and default modules.
cp "$HOME/src/omarchy/config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
cp "$HOME/src/omarchy/config/hypr/bindings.lua" "$HOME/.config/hypr/bindings.lua"
cp "$HOME/src/omarchy/config/hypr/input.lua" "$HOME/.config/hypr/input.lua"
cp "$HOME/src/omarchy/config/hypr/looknfeel.lua" "$HOME/.config/hypr/looknfeel.lua"
cp "$HOME/src/omarchy/config/hypr/monitors.lua" "$HOME/.config/hypr/monitors.lua"
cp "$HOME/src/omarchy/config/omarchy/shell.json" "$HOME/.config/omarchy/shell.json"
[[ -f "$HOME/.config/hypr/hyprland.conf" ]] && mv "$HOME/.config/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf.corsola"

cat > "$HOME/.config/hypr/autostart.lua" <<'EOF'
-- Corsola uses Omarchy's upstream shell/config with ARM-safe startup.
o.exec_on_start("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
o.exec_on_start("dbus-update-activation-environment --systemd --all")
o.exec_on_start("if test -e $HOME/.local/state/omarchy/current/background; then swaybg -i $HOME/.local/state/omarchy/current/background -m fill; else swaybg -c '#111318'; fi")
o.exec_on_start("swaync")
o.exec_on_start("nm-applet --indicator")
o.exec_on_start("hypridle")
o.exec_on_start("OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-launch-shell")
o.exec_on_start("OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-provision-first-run")
o.exec_on_start("OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-powerprofiles-init")
EOF

export OMARCHY_PATH=/usr/share/omarchy
export PATH=/usr/local/bin:$HOME/.local/bin:/usr/bin
if [[ ! -s "$HOME/.local/state/omarchy/current/theme.name" ]]; then
  OMARCHY_SETUP_CONTEXT=runtime omarchy-theme-set "Tokyo Night"
fi
omarchy-theme-set-templates
if [[ ! -L "$HOME/.local/state/omarchy/current/background" ]]; then
  bg=$(find "$HOME/.local/state/omarchy/current/theme/backgrounds" -type f | sort | head -n 1)
  [[ -n "$bg" ]] && omarchy-theme-bg-set "$bg"
fi

mkdir -p "$HOME/.config/foot" "$HOME/.config/btop"
[[ -f "$HOME/.local/state/omarchy/current/theme/foot.ini" ]] && cp -f "$HOME/.local/state/omarchy/current/theme/foot.ini" "$HOME/.config/foot/foot.ini"
[[ -f "$HOME/.local/state/omarchy/current/theme/btop.theme" ]] && cp -f "$HOME/.local/state/omarchy/current/theme/btop.theme" "$HOME/.config/btop/current.theme"
cp "$HOME/src/omarchy/default/bashrc" "$HOME/.bashrc"

sudo systemctl enable greetd.service

# AUR/package-manager parity. yay itself is built from source because the
# Arch Linux ARM repos do not ship it; mise-bin publishes a native arm64 build.
mkdir -p "$HOME/src/aur"
if [[ ! -d "$HOME/src/aur/yay/.git" ]]; then
  git clone --depth=1 https://aur.archlinux.org/yay.git "$HOME/src/aur/yay"
fi
(cd "$HOME/src/aur/yay" && makepkg --syncdeps --needed --noconfirm)
sudo pacman -U --noconfirm "$HOME"/src/aur/yay/yay-*.pkg.tar.*
yay -S --noconfirm --needed mise-bin

# omarchy-nvim is architecture-independent but is not published in the ARM
# binary repository. Build the official upstream PKGBUILD with native ARM Node.
if ! pacman -Q omarchy-nvim >/dev/null 2>&1; then
  rm -rf "$HOME/src/omarchy-pkgs"
  git clone --depth=1 --filter=blob:none --sparse \
    https://github.com/omacom-io/omarchy-pkgs.git "$HOME/src/omarchy-pkgs"
  (cd "$HOME/src/omarchy-pkgs" && git sparse-checkout set pkgbuilds/omarchy-nvim)
  (cd "$HOME/src/omarchy-pkgs/pkgbuilds/omarchy-nvim" && \
    PATH="$HOME/.local/share/mise/installs/node/26.8.1/bin:$PATH" \
    makepkg --syncdeps --needed --noconfirm)
  sudo pacman -U --noconfirm "$HOME"/src/omarchy-pkgs/pkgbuilds/omarchy-nvim/omarchy-nvim-*.pkg.tar.*
fi

# This is the repo's own final user provisioning step: default browser/editor,
# XDG directories, MIME associations, shell integration, and user hooks.
OMARCHY_PATH=/usr/share/omarchy omarchy-provision-user --force

OMARCHY_PATH=/usr/share/omarchy hyprland -c "$HOME/.config/hypr/hyprland.lua" --verify-config >/dev/null
printf '%s\n' 'Omarchy ARM install complete. Reboot to exercise greetd → Hyprland Lua → Omarchy shell.'
