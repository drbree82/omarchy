# Chromarchy — Omarchy for Google Corsola ARM Chromebooks

**Chromarchy is a fork of [Omarchy](https://github.com/basecamp/omarchy), adapted for postmarketOS-derived Arch Linux ARM on Google Corsola Chromebooks.**

This is **not** the original `omacom/omarchy`/x86_64 installation path. It targets the ARM64 MediaTek Corsola platform, including devices such as the Lenovo IdeaPad Slim 3 14M868 (Google Magneton/Steelix) with the MediaTek MT8186 SoC.

## Supported target

- Google Corsola-family Chromebooks
- Lenovo IdeaPad Slim 3 14M868 / Magneton / Steelix variants
- ARM64 (`aarch64`), not x86_64
- ChromeOS/Depthcharge-compatible boot layout
- postmarketOS-derived kernel and userspace foundation
- MediaTek MT8186 SoC, including the RT5682S/RT1019 audio hardware

The Corsola port preserves the ChromeOS GPT/kernel layout required by Depthcharge. It must not be installed using generic x86_64 Omarchy disk-install instructions.

## Installation

The board-specific installer is:

```sh
./install-corsola.sh
```

Run it on a supported Corsola installation from an ARM64 environment. It installs the ARM-compatible package set, configures Hyprland and the Omarchy shell, preserves the existing ChromeOS boot layout, and installs Corsola-specific hardware configuration.

The default account for a fresh Chromarchy installation is:

```text
username: chromarchy
password: chromarchy
```

This default password is intended for the initial installation only. Change it immediately after the first login with `passwd`. Installers may override the defaults with `CHROMARCHY_USERNAME` and `CHROMARCHY_PASSWORD`.

## Audio and hardware notes

Corsola uses the MediaTek MT8186 audio stack rather than the Intel/AMD audio paths used by typical x86_64 Omarchy machines. The installer therefore keeps the board-specific SOF topology, UCM profile, and speaker-route initialization together with the Corsola installer.

If audio is unavailable, inspect the kernel log first:

```sh
journalctl -k -b | grep -E 'ASoC|SOF|mt8186|rt1019|rt5682|audio'
```

## Relationship to upstream Omarchy

Chromarchy follows Omarchy's shell, configuration, applications, and documentation where they work on ARM. Board-specific changes are maintained in this fork so upstream Omarchy remains untouched and users are not misled about hardware support.

The upstream Omarchy manual remains available in [`manual/`](manual/). It is useful for the shared desktop experience, but hardware and installation instructions must be interpreted for Corsola ARM rather than x86_64 PCs.

## The Omarchy Manual

The manual lives in [`manual/`](manual/), which is its authoritative source.

- [Welcome to Omarchy](manual/01-welcome-to-omarchy.md)
- [Getting Started](manual/02-getting-started.md)
- [The top bar](manual/05-the-top-bar.md)
- [Themes](manual/06-themes.md)
- [Hotkeys](manual/07-hotkeys.md)
- [Browsers](manual/23-browsers.md)
- [Networking](manual/35-networking.md)
- [Backgrounds](manual/39-backgrounds.md)
- [Troubleshooting](manual/45-troubleshooting.md)
- [FAQ](manual/46-faq.md)
- [Omarchy on...](manual/49-omarchy-on.md)
- [Unattended Installs](manual/51-unattended-installs.md)

## License

Omarchy is released under the [MIT License](https://opensource.org/licenses/MIT). Chromarchy's board-specific additions are released under the same license unless noted otherwise.
