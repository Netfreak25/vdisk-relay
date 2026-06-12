# VDisk Relay Quickstart

VDisk Relay turns a Raspberry Pi into a virtual USB flash drive for devices
that write files to removable USB storage. The Pi exposes `/usbdisk.img`
through USB gadget mode, the host device writes files to that drive, and VDisk
Relay detects the changes, imports new files into `/files`, and can optionally
send matching files through Telegram.

This document is an entry point for the repository. It is intentionally shorter
than the full operation and configuration references linked at the end.

## Project Summary

Target system:

- Raspberry Pi OS Bookworm
- Raspberry Pi Zero W as the minimal target
- Raspberry Pi Zero 2 W or a larger Raspberry Pi recommended for smoother
  WebUI use during sync, preview, Telegram, or archive work
- Separate power for the Pi and a data cable from the Pi USB/OTG port to the
  USB host device recommended for stable operation

Default runtime model:

- `/usbdisk.img` is exposed as USB mass storage.
- New files are imported read-only from the image into `DATA_ROOT`, usually
  `/files`.
- The WebUI is served locally at `http://<host>/`.
- Telegram delivery, previews, archive, health checks, and Network Guardian are
  optional runtime features controlled by configuration and gates.

## What It Solves

VDisk Relay is for USB host devices that write files to a normal USB flash
drive but do not provide a convenient network export. Instead of moving a
physical USB stick between systems, the Raspberry Pi presents a virtual drive,
imports new files after the host writes them, and makes the data available
locally.

VDisk Relay does not expand limits imposed by the USB host device. For example,
when the host is a Blink Sync Module 2, plan within that module's own camera
and local-storage limits and use one relay image per independent host system.

## Typical Host Devices

- Camera hubs with USB local storage, for example Blink Sync Module 2
- Small DVR/NVR devices that export clips to a USB drive
- Field recorders that write audio or video files to removable USB storage
- Lab or industrial data loggers
- Embedded controllers or appliances that export reports to USB media

## Architecture in 30 Seconds

```text
USB Host Device
      |
      v
Raspberry Pi USB Gadget
      |
      v
/usbdisk.img
      |
      v
systemd.path / trigger
      |
      v
read-only mount
      |
      v
live sync
      |
      +-- /files
      +-- Telegram Queue
      +-- Preview Cache
      +-- optional Archive
```

The host writes to the virtual USB drive. VDisk Relay detects image changes,
mounts the image read-only, copies new files into `/files`, and then lets the
WebUI, preview cache, Telegram queue, and optional archive path work from the
imported files.

## Hardware Notes

Recommended wiring:

```text
Raspberry Pi PWR port  -> dedicated Pi power supply
Raspberry Pi USB port  -> USB data cable -> USB host device
USB host device        -> its own power supply, if it has one
```

For a Raspberry Pi Zero W or Zero 2 W, the port labels matter:

| Pi port | Role | Connect to |
|---|---|---|
| `PWR IN` | power only | Pi power supply |
| `USB` | USB OTG/gadget data | USB host device |

Only the USB/OTG port can expose the Pi as a USB mass-storage gadget. The power
port cannot carry gadget data.

Compact USB OTG power/data dongles, Y-cables, or splitter adapters can be used
only when they carry USB data and provide enough current. Treat shop links as
examples of adapter types, not as project requirements or product
recommendations.

See [docs/hardware.md](docs/hardware.md) for hardware, capacity, and load
guidance.

## Feature Highlights

- USB mass-storage gadget backed by `/usbdisk.img`
- Read-only import path that copies new files into `DATA_ROOT`, usually
  `/files`
- Source rules for labels, filename matching, file extensions, Telegram mode,
  retries, and send state
- Server-side WebUI for Data/Media, Sources, Telegram, Wi-Fi, Maintenance,
  Update, Services, and diagnostics
- Responsive WebUI with web app manifest, app icons, service worker, and
  browser install-prompt support when the client browser treats the local site
  as installable
- Preview cache with generated thumbnails and a fast media catalog
- Web display timezone for Media/Data timestamps and date grouping
- Persistent Telegram delivery queue for the normal path
- Optional Ultra Fast Lane test path for low-latency direct sends
- Optional rsync-daemon archive destination
- Health checks for stale data and USB/image consistency
- Network Guardian emergency AP and recovery flow
- Config backup/restore and controlled WebUI update flow
- English default WebUI plus German WebUI language catalog

## Components

| Component | Purpose |
|---|---|
| USB gadget | Exposes `/usbdisk.img` through `g_mass_storage`. |
| Watch/trigger | Detects image changes with `systemd.path` and sets pending state. |
| Live sync | Mounts the image read-only, copies new files to `/files`, and unmounts cleanly. |
| Fast Lane | Starts an early `live-sync --fast` after a trigger. The retry timer remains the fallback. |
| Ultra Fast Lane | Optional low-latency test path that sends directly from a read-only shadow mount, then syncs to `/files`. Disabled by default. |
| Telegram queue | Persistent Telegram delivery queue for the normal path. |
| Preview cache | Builds `files.json`, preview images, and preview backlog state. |
| Archive | Copies `/files/` to an external rsync-daemon target. |
| Health | Checks the newest active file and can notify or reboot when data gets stale. |
| Network Guardian | Optional emergency Wi-Fi/AP recovery mode. |
| WebUI | Responsive local UI for Data, Sources, Telegram, Wi-Fi, Maintenance, Update, and State. |

For installed units and timers, see
[docs/systemd-reference.md](docs/systemd-reference.md).

## Quick Start

Clone the public repository:

```bash
git clone https://github.com/Netfreak25/vdisk-relay.git vdisk-relay
cd vdisk-relay
```

Install packages and configure Raspberry Pi USB gadget boot settings:

```bash
deploy/bookworm/dependencies.sh --all
```

This installs package dependencies and can add `dtoverlay=dwc2` to the Pi boot
config. It also writes `/etc/modules-load.d/vdisk-relay.conf` for `dwc2` and
`libcomposite`.

`deploy/bookworm/install.sh` does not change the Raspberry Pi boot
configuration. If only gadget boot configuration is needed, use:

```bash
deploy/bookworm/dependencies.sh --configure-gadget
```

If `dtoverlay=dwc2` was newly added or gadget modules cannot be loaded yet,
reboot before expecting USB gadget mode to work.

Install files without starting live behavior on a fresh system:

```bash
deploy/bookworm/install.sh --no-live
```

Create the first configuration:

```bash
deploy/bookworm/wizard.sh
```

Install again after configuration:

```bash
deploy/bookworm/install.sh
```

Use `--no-live` for the first install so files, WebUI, and the wizard are
available before runtime services start. The installer preserves existing
secrets and gate decisions during later updates.

For physical host validation, follow
[docs/quickstart-usb-host.md](docs/quickstart-usb-host.md).

## First Configuration

The wizard creates or updates:

```text
/etc/vdisk-relay.conf
/etc/vdisk-relay.env
/root/vdisk-relay-rsync.pass
```

It always asks for:

- image path, usually `/usbdisk.img`
- local data root, usually `/files`

It can optionally configure:

- rsync-daemon archive destination and password file
- Telegram bot token and chat ID
- one initial source
- selected live gates

Skipped features remain disabled and can be configured later in the WebUI.
Alternative manual configuration uses `/etc/vdisk-relay.conf` and
`/etc/vdisk-relay.env`; see
[docs/configuration-reference.md](docs/configuration-reference.md).

## Verify the Installation

On the Pi:

```bash
/usr/local/sbin/vdisk-relay status-lights
systemctl --failed
systemctl list-timers --all | grep vdisk-relay
tail -n 120 /var/log/vdisk-relay.log
```

For gadget mode:

```bash
lsmod | grep -E 'dwc2|g_mass_storage'
systemctl status vdisk-relay-gadget-live.service --no-pager
```

Expected result:

- The Pi exposes `/usbdisk.img` as USB mass storage.
- The host sees a removable USB drive.
- New files are imported into `/files`.
- The WebUI is reachable at `http://<host>/`.

If the host does not see the drive or files are not imported, use
[docs/troubleshooting.md](docs/troubleshooting.md).

## Runtime Paths

Installed programs:

```text
/usr/local/sbin/vdisk-relay
/usr/local/sbin/vdisk-relay-web-admin
/usr/local/sbin/vdisk-relay-preview-cache
/usr/local/sbin/vdisk-relay-status-cache
/usr/local/sbin/vdisk-relay-update-run
```

Configuration and secrets:

```text
/etc/vdisk-relay.conf
/etc/vdisk-relay.env
/root/vdisk-relay-rsync.pass
/usr/local/share/vdisk-relay/i18n/en.json
/usr/local/share/vdisk-relay/i18n/de.json
```

Runtime data, not tracked by git:

```text
/run/vdisk-relay/
/run/vdisk-relay-www/
/var/lib/vdisk-relay/
/var/cache/vdisk-relay-previews/
/var/log/vdisk-relay.log
/var/log/vdisk-relay-timeline.jsonl
/files/
/usbdisk.img
```

For deployment details and the full installed-program list, see
[deploy/bookworm/README.md](deploy/bookworm/README.md).

## Live Gates

Production behavior is controlled by gate files:

```text
/etc/vdisk-relay.live-enabled
/etc/vdisk-relay.allow-gadget
/etc/vdisk-relay.allow-watch
/etc/vdisk-relay.allow-trigger
/etc/vdisk-relay.allow-sync
/etc/vdisk-relay.allow-archive
/etc/vdisk-relay.allow-health-reboot
/etc/vdisk-relay.allow-boot-notify
```

Network Guardian uses its own gate:

```text
/etc/vdisk-relay.allow-network-guardian
```

Installer behavior:

- Existing gates are preserved during updates.
- If no gate state exists and required configuration is complete, default gates
  are created once.
- `--no-live` keeps a fresh installation passive.
- `--force-live` intentionally recreates the default gates.

## WebUI Notes

Default URL:

```text
http://<host>/
```

The WebUI includes a web app manifest, 192 px and 512 px icons, mobile viewport
metadata, and a service worker. Browser installation is optional and depends on
the client browser. If the browser does not offer installation for the local
HTTP origin, use the WebUI as a normal local web page or place it behind
trusted HTTPS. VDisk Relay does not ship a Play Store Android wrapper.

Settings are grouped into General, Display, Timeline, Performance, Previews,
Telegram, System, and Actions. This grouping is UI-only; backend config keys
and existing POST endpoints remain unchanged.

The System / Update page can switch the repository between the `main` and `dev`
branches. A branch switch uses the controlled update service: fetch, checkout,
fast-forward pull, install, and service refresh.

## Operations and Diagnostics

Common status commands:

```bash
/usr/local/sbin/vdisk-relay status-lights
systemctl list-timers --all | grep vdisk-relay
systemctl --failed
tail -n 120 /var/log/vdisk-relay.log
```

Generated WebUI/status cache files:

```text
/run/vdisk-relay/status.json
/run/vdisk-relay/status-login.txt
/run/vdisk-relay/status-last-attempt.json
/run/vdisk-relay-www/index.html
/run/vdisk-relay-www/status.txt
/run/vdisk-relay-www/debug.html
```

`vdisk-relay status-lights` is cache-based by default. Use
`vdisk-relay status-lights --live` only for explicit administrator diagnosis.

Status components use these stable states: `OK`, `PENDING`, `WARN`, `FAIL`,
`DISABLED`, and `UNKNOWN`. The text view renders them as `OK`, `PEND`, `WARN`,
`FAIL`, `OFF`, and `UNKN`.

For field symptoms and read-only checks, see
[docs/troubleshooting.md](docs/troubleshooting.md).

## Backup and Restore

The repository does not contain secrets or runtime data. Configuration backup:

```bash
/usr/local/sbin/vdisk-relay config-backup
```

Restore dry run:

```bash
/usr/local/sbin/vdisk-relay config-restore /root/vdisk-relay-config-backups/<backup>.tar.gz
```

Apply restore:

```bash
/usr/local/sbin/vdisk-relay config-restore /root/vdisk-relay-config-backups/<backup>.tar.gz --apply
```

A full system restore also needs:

```text
/usbdisk.img
/files/
```

Backups can contain secrets and must not be committed to git. See
[docs/config-backup-restore.md](docs/config-backup-restore.md) and
[docs/secrets.md](docs/secrets.md).

## Further Documentation

| Document | Purpose |
|---|---|
| [docs/README.md](docs/README.md) | Documentation index. |
| [docs/hardware.md](docs/hardware.md) | Raspberry Pi hardware choices, USB OTG wiring, power expectations, and host limits. |
| [docs/quickstart-usb-host.md](docs/quickstart-usb-host.md) | Physical setup and first validation with a USB host. |
| [deploy/bookworm/README.md](deploy/bookworm/README.md) | Bookworm deployment scripts, installer behavior, and wizard usage. |
| [docs/manual-installation.md](docs/manual-installation.md) | Manual first installation and verification steps. |
| [docs/prerequisites.md](docs/prerequisites.md) | Package, command, and Raspberry Pi USB gadget prerequisites. |
| [docs/configuration-reference.md](docs/configuration-reference.md) | `/etc/vdisk-relay.conf` variables and examples. |
| [docs/systemd-reference.md](docs/systemd-reference.md) | Installed units, timers, and status cache ownership. |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Field symptoms, checks, and likely causes. |
| [docs/config-backup-restore.md](docs/config-backup-restore.md) | Configuration backup and restore. |
| [docs/secrets.md](docs/secrets.md) | Secret files that must not be committed. |
| [docs/format-vdisk.md](docs/format-vdisk.md) | Manual `/usbdisk.img` recovery helper. |
| [docs/network-emergency-mode.md](docs/network-emergency-mode.md) | Network Guardian and emergency AP design. |
| [docs/network-emergency-checks.md](docs/network-emergency-checks.md) | Network Guardian thresholds and acceptance checks. |
| [docs/bulk-delete.md](docs/bulk-delete.md) | Data workspace bulk-selection and queued delete behavior. |
| [docs/screenshots/README.md](docs/screenshots/README.md) | Screenshot list and sanitizing rules. |
