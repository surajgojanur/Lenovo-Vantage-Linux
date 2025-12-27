# Lenovo Vantage for Linux

Lenovo Vantage controls for conservation mode, always-on USB, fan profiles, FN lock, camera, microphone, touchpad, and Wi‑Fi on supported Lenovo laptops.

![Main menu](images/main_menu.png)

## Feature matrix

| Feature | Notes |
| --- | --- |
| Conservation Mode | Limits charge to prolong battery life |
| Always-On USB | Keeps USB powered during sleep/hibernate |
| Fan Mode | Silent, Standard, Dust Cleaning, Efficient Dissipation |
| FN Lock | Toggle function key behavior |
| Camera | Loads/unloads `uvcvideo` module |
| Microphone | Mute/unmute via `pactl` |
| Touchpad | Enable/disable via `xinput` (X11 only) |
| Wi‑Fi | Toggle via `nmcli` (NetworkManager) |

## Requirements

- X11 session (Wayland currently unsupported for touchpad controls)
- Lenovo platform exposing `/sys/bus/platform/devices/VPC2004:*`
- `zenity`, `xinput`, `NetworkManager`, `pactl` (PulseAudio or PipeWire), `pkexec`

### Session compatibility

| Feature                 | X11 | Wayland |
| ---                     | --- | ---     |
| Battery Conservation    | ✅  | ✅      |
| Fan Mode                | ✅  | ✅      |
| Touchpad Control        | ✅  | ❌      |
| xinput Features         | ✅  | ❌      |

Wayland restricts input device control for security reasons, so touchpad and other xinput-based actions are disabled there.

Package names by distro:

- Arch: `zenity xorg-xinput networkmanager`
- Debian/Ubuntu: `zenity xinput network-manager`
- Fedora: `zenity xinput NetworkManager pipewire-pulseaudio`
- openSUSE: `zenity xinput NetworkManager pipewire-pulseaudio`

## Quick start

1) Clone and enter the project

```bash
git clone https://github.com/niizam/vantage.git
cd vantage
```

2) Optional: check your system before installing

```bash
./scripts/self-check.sh
```

3) Install dependencies and desktop entry (needs sudo/root)

```bash
sudo make install
```

4) Run the app

- From the desktop menu: search for “Lenovo Vantage”.
- From a terminal: `vantage` (requires an X11 session).

5) Uninstall later

```bash
sudo make uninstall
```

## Install

```bash
git clone https://github.com/niizam/vantage.git
cd vantage

# Optional: preview actions without changes
make dry-run

# Install (requires sudo/root)
sudo make install
```

Launch from your desktop menu as “Lenovo Vantage” or run `vantage` in a terminal (X11 required for touchpad controls).

## Self-check

Before first run (or when troubleshooting), execute:

```bash
./scripts/self-check.sh
```

The script validates dependencies, session type, VPC device presence, and NetworkManager status.

## Uninstall

```bash
sudo make uninstall
```

## Troubleshooting

- Self-check fails with VPC missing: hardware interface not exposed; ensure this is a supported Lenovo model.
- On Wayland sessions touchpad control is unavailable; this is expected and limited by Wayland.
- NetworkManager inactive: start it with `sudo systemctl start NetworkManager` or enable the service.
- pkexec prompts repeatedly: ensure PolicyKit is configured and you have admin rights.

## Development

- Lint scripts: `make lint`
- Format check: `make format`
- CI: GitHub Actions runs ShellCheck and shfmt on pushes/PRs.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for versioned notes.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
