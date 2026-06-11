# Manual Installation

This guide describes a clean first installation on Raspberry Pi OS Bookworm.

Before starting, review [hardware.md](hardware.md). The USB host device must be
connected to the Pi USB/OTG port, not to a power-only port. A separate Pi power
supply is recommended for stable operation.

## 1. Clone the Repository

```bash
git clone https://github.com/Netfreak25/vdisk-relay.git vdisk-relay
cd vdisk-relay
```

## 2. Install Dependencies

Check only:

```bash
deploy/bookworm/dependencies.sh --check
```

Install packages and configure the Raspberry Pi USB gadget boot settings:

```bash
deploy/bookworm/dependencies.sh --all
```

This step installs packages and adds `dtoverlay=dwc2` to the Pi boot config when
needed. It also writes `/etc/modules-load.d/vdisk-relay.conf` for `dwc2` and
`libcomposite`.

If `dtoverlay=dwc2` was newly added or the script reports that gadget modules
cannot be loaded yet, reboot before continuing with live activation.

The normal installer does not edit the Pi boot config. Run the dependency script
when gadget boot setup is required.

## 3. Install Files Passively

```bash
deploy/bookworm/install.sh --no-live
```

This installs scripts, units, WebUI files, default config files, i18n files, and
directories without starting the live runtime path on a fresh system.

## 4. Create First Configuration

Interactive wizard:

```bash
deploy/bookworm/wizard.sh
```

The wizard writes:

```text
/etc/vdisk-relay.conf
/etc/vdisk-relay.env
/root/vdisk-relay-rsync.pass
```

It also creates state/runtime directories and can set the first live gate set.
Archive, Telegram, the first source, and live gates can be skipped. Skipped
features remain disabled and can be configured later in the WebUI.

Alternative: edit `/etc/vdisk-relay.conf` and `/etc/vdisk-relay.env` manually.
Use [configuration-reference.md](configuration-reference.md) as the reference.

## 5. Install Again and Activate

```bash
deploy/bookworm/install.sh
```

If required configuration is complete and no previous gate state exists, the
installer creates default live gates once. Existing gates are preserved on later
updates.

Use this only when you intentionally want to recreate default gates:

```bash
deploy/bookworm/install.sh --force-live
```

## 6. Verify

```bash
/usr/local/sbin/vdisk-relay status-lights
systemctl list-timers --all | grep vdisk-relay
systemctl --failed
journalctl -u vdisk-relay-web.service -n 80 --no-pager
```

Open the WebUI:

```text
http://<host>/
```

For the first physical host test, follow
[quickstart-usb-host.md](quickstart-usb-host.md). It covers wiring, gadget mode
checks, and first file import validation.

## 7. Update Later

```bash
cd vdisk-relay
deploy/bookworm/install.sh
```

The installer runs `git pull --ff-only` by default. Use `--no-pull` to install
from the current checkout.

The WebUI update action uses the same install script.
