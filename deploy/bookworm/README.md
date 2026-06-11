# Bookworm Deployment

This directory contains the deployment scripts for Raspberry Pi OS Bookworm,
Debian Bookworm, and closely compatible systems.

## Files

```text
deploy/bookworm/dependencies.sh
deploy/bookworm/install.sh
deploy/bookworm/wizard.sh
deploy/bookworm/templates/vdisk-relay.env.template
deploy/bookworm/templates/vdisk-relay-rsync.pass.template
```

## Recommended First Install

```bash
git clone https://github.com/Netfreak25/vdisk-relay.git vdisk-relay
cd vdisk-relay

deploy/bookworm/dependencies.sh --all
deploy/bookworm/install.sh --no-live
deploy/bookworm/wizard.sh
deploy/bookworm/install.sh
```

Use `--no-live` for the first install so files, WebUI, and the wizard are
available before runtime services start.

## Dependency Bootstrap

Check only:

```bash
deploy/bookworm/dependencies.sh --check
```

Install packages and configure Raspberry Pi USB gadget boot settings:

```bash
deploy/bookworm/dependencies.sh --all
```

Only configure the Pi boot settings:

```bash
deploy/bookworm/dependencies.sh --configure-gadget
```

`dependencies.sh --configure-gadget` edits the detected Pi boot config
(`/boot/firmware/config.txt` or `/boot/config.txt`) and adds `dtoverlay=dwc2`
when it is missing. It also writes `/etc/modules-load.d/vdisk-relay.conf` for
`dwc2` and `libcomposite`.

If `dtoverlay=dwc2` was newly added or module loading is not green yet, reboot
before expecting USB gadget mode to work.

`install.sh` does not perform this boot configuration step.

## Installer

```bash
deploy/bookworm/install.sh [OPTIONS]
```

The installer:

- runs `git pull --ff-only` unless `--no-pull` is set
- installs `/usr/local/sbin/vdisk-relay` and helper scripts
- installs `/usr/local/bin` helper tools
- installs `/etc/systemd/system/vdisk-relay-*` units
- installs `/etc/update-motd.d/99-vdisk-relay` unless `--no-motd` is set
- installs and enables the WebUI unless `--no-web` is set
- copies i18n files to `/usr/local/share/vdisk-relay/i18n/`
- creates `/files`, runtime, state, queue, and preview-cache directories
- creates `/etc/vdisk-relay.env` from the template only when it is missing
- fills missing defaults in `/etc/vdisk-relay.conf`
- preserves existing secrets and existing gate decisions
- refreshes status/debug caches and restarts active WebUI/status services

Options:

| Option | Effect |
|---|---|
| `--no-live` | Install/update files but do not create live gates on a fresh system. |
| `--force-live` | Recreate default live gates intentionally. |
| `--force-config` | Replace `/etc/vdisk-relay.conf` after creating a backup. |
| `--no-motd` | Do not install the MOTD hook. |
| `--no-web` | Do not install/enable the WebUI service. |
| `--no-restart` | Do not restart active WebUI/status services after install. |
| `--no-pull` | Install from the current checkout without `git pull`. |

The deprecated `--enable-live` alias still maps to `--force-live`.

## Wizard

```bash
deploy/bookworm/wizard.sh
```

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

The wizard is useful for first setup and for rebuilding a config file. The
WebUI can manage most settings afterwards.

## Update

From an existing checkout:

```bash
cd vdisk-relay
deploy/bookworm/install.sh
```

The WebUI update action uses the same install script after fetching the latest
commit.

## Installed Programs

```text
/usr/local/sbin/vdisk-relay
/usr/local/sbin/vdisk-relay-debug-cache
/usr/local/sbin/vdisk-relay-git-askpass
/usr/local/sbin/vdisk-relay-network-guardian
/usr/local/sbin/vdisk-relay-preview-cache
/usr/local/sbin/vdisk-relay-status-cache
/usr/local/sbin/vdisk-relay-update-check
/usr/local/sbin/vdisk-relay-update-run
/usr/local/sbin/vdisk-relay-web-admin
/usr/local/sbin/vdisk-relay-web-status-cache
/usr/local/sbin/video-vdisk
/usr/local/bin/watch-preview-debug-log
/usr/local/bin/watch-preview-log
```

The `video-vdisk` wrapper only reports that VDisk Relay replaced the old command.

## References

```text
../../docs/hardware.md
../../docs/quickstart-usb-host.md
../../docs/prerequisites.md
../../docs/manual-installation.md
../../docs/configuration-reference.md
../../docs/systemd-reference.md
../../docs/troubleshooting.md
```
