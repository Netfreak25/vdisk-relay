# VDisk Relay Documentation

## Operations

| Document | Purpose |
|---|---|
| [../README.md](../README.md) | Project overview, feature highlights, runtime paths, first setup, gates, and Fast Lane behavior. |
| [hardware.md](hardware.md) | Raspberry Pi hardware choices, USB OTG wiring, power expectations, and host limits. |
| [quickstart-usb-host.md](quickstart-usb-host.md) | First physical setup and validation with any USB host that writes files to USB storage. |
| [../deploy/bookworm/README.md](../deploy/bookworm/README.md) | Bookworm deployment scripts, installer behavior, and wizard usage. |
| [manual-installation.md](manual-installation.md) | Manual first installation and verification steps. |
| [prerequisites.md](prerequisites.md) | Package, command, and Raspberry Pi USB gadget prerequisites. |
| [configuration-reference.md](configuration-reference.md) | `/etc/vdisk-relay.conf` variables with examples. |
| [config-backup-restore.md](config-backup-restore.md) | Configuration backup and restore. |
| [secrets.md](secrets.md) | Secret files that must not be committed. |
| [format-vdisk.md](format-vdisk.md) | Manual image recovery helper. |
| [troubleshooting.md](troubleshooting.md) | Field symptoms, checks, and likely causes. |
| [bulk-delete.md](bulk-delete.md) | Data workspace bulk-selection, confirmation flow, and queued delete behavior. |
| [screenshots/README.md](screenshots/README.md) | Screenshot list and sanitizing rules for documentation images. |

## Architecture

| Document | Purpose |
|---|---|
| [systemd-reference.md](systemd-reference.md) | Repo reference for systemd units and timers. |
| [status-lights.txt](status-lights.txt) | Example output of `vdisk-relay status-lights`. |
| [network-emergency-mode.md](network-emergency-mode.md) | Network Guardian and emergency AP design. |
| [network-emergency-checks.md](network-emergency-checks.md) | Guardian thresholds and acceptance checks. |

## Rules

- Do not document real secrets, tokens, chat IDs, hostnames, private IPs, or archive destinations.
- Do not commit runtime data, logs, previews, queues, or generated cache files.
- New operational documentation should be written in English.
- Deep technical plans should state whether they are planned, implemented, or historical.
