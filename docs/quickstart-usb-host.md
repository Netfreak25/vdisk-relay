# USB Host Quickstart

This quickstart covers the physical setup and first validation for a USB host
device that writes files to a USB flash drive. Blink Sync Module 2 is one
practical example, but the same flow applies to other camera hubs, DVR/NVR
devices, data loggers, or embedded controllers that write files to USB storage.

## 1. Prepare the Pi

Install dependencies and gadget boot configuration:

```bash
deploy/bookworm/dependencies.sh --all
```

If this command added `dtoverlay=dwc2` or reports that gadget modules cannot be
loaded yet, reboot before expecting USB gadget mode to work.

Install files without starting live behavior yet:

```bash
deploy/bookworm/install.sh --no-live
```

Create configuration:

```bash
deploy/bookworm/wizard.sh
```

## 2. Wire the Hardware

Recommended wiring:

```text
Pi PWR port  -> dedicated Pi power supply
Pi USB port  -> data cable -> USB host device
Host device  -> its own power supply, when available
```

For a Pi Zero W or Pi Zero 2 W, do not connect the host device to `PWR IN`.
Connect the host device to the USB/OTG port. `PWR IN` is power-only.

Compact OTG power/data dongles or splitters are acceptable only when they carry
USB data and provide enough current. Treat shop links as examples of adapter
types, not as project-approved products.

## 3. Activate Gates and Confirm Gadget Mode

Install again after configuration and wiring. This enables the relevant units
when the configuration is complete and the live gates allow them:

```bash
deploy/bookworm/install.sh
```

On the Pi:

```bash
lsmod | grep -E 'dwc2|g_mass_storage'
/usr/local/sbin/vdisk-relay status-lights
systemctl status vdisk-relay-gadget-live.service --no-pager
```

The host should see a USB drive. If it does not, check the USB/OTG port, cable,
adapter, and `GADGET_MODPROBE_ARGS`.

## 4. Let the Host Write a Test File

Trigger or wait for the host to write a small file. The file type depends on the
host:

- camera hub: a short motion clip
- DVR/NVR: a test export or short recording
- data logger: a current sample file
- controller or appliance: a generated report

Then check:

```bash
/usr/local/sbin/vdisk-relay status-lights
tail -n 120 /var/log/vdisk-relay.log
find /files -type f | tail -n 20
```

Open the WebUI:

```text
http://<host>/
```

## 5. Keep First Runs Conservative

On a Pi Zero W, start with conservative settings:

- keep Ultra Fast Lane disabled until the normal path is proven
- keep preview generation small
- avoid large archive transfers during first validation
- leave debug and Telegram reply-body tracing off unless troubleshooting

After stable imports are confirmed, enable Telegram, archive, previews, and
maintenance features one at a time.

## 6. Validate the Host Limit

VDisk Relay cannot change the limits of the USB host system. For example, a
camera hub may have a maximum number of cameras or a maximum USB storage size.
Plan capacity, source filters, and archive behavior around the host's own
limits.
