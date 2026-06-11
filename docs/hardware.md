# Hardware Guide

VDisk Relay is designed for USB host devices that write files to a normal USB
flash drive. The Raspberry Pi presents `/usbdisk.img` as that flash drive, then
imports new files into local storage after the host writes them.

Practical host examples:

- security camera hubs with USB local storage, for example Blink Sync Module 2
- small DVR/NVR devices that export clips to a USB drive
- field recorders that write audio or video files to removable USB storage
- lab or industrial data loggers that periodically append files to a USB drive
- kiosks, controllers, or embedded appliances that export reports to USB media

The host must act as the USB host and must write a filesystem that Linux can
mount from the backing image. The default project image is a FAT-style USB mass
storage image.

## Recommended Setup

Use this setup when reliability matters:

```text
Raspberry Pi PWR port  -> dedicated Pi power supply
Raspberry Pi USB port  -> USB data cable -> USB host device
USB host device        -> its own power supply, if it has one
```

Recommended hardware:

- Raspberry Pi Zero 2 W or a larger Raspberry Pi
- microSD card, 16 GB or larger
- stable power supply for the Pi
- USB data cable from the Pi USB/OTG port to the host device
- enough local storage for `/files`, previews, queue state, and logs

For a Raspberry Pi Zero or Zero 2 W, the port labels matter:

| Pi port | Role | Connect to |
|---|---|---|
| `PWR IN` | power only | Pi power supply |
| `USB` | USB OTG/gadget data | USB host device |

Only the USB/OTG port can expose the Pi as a USB mass-storage gadget. The power
port cannot carry gadget data.

## Compact Pi Zero W Setup

A compact Pi Zero W build can use a USB OTG power/data dongle, Y-cable, or
splitter adapter. Links to specific shops or products should be treated as
examples of the adapter type only, not as project requirements or product
recommendations.

This setup is more sensitive:

- the host USB port may not provide enough current for a Pi under load
- Wi-Fi, sync, previews, archive jobs, and Telegram uploads can make the WebUI
  slow
- undervoltage can cause disconnects, filesystem errors, or service restarts
- adapters that only provide charging power will not work for USB data

Use a separate Pi power supply when possible. If a one-cable build is required,
verify the adapter carries data, watch for undervoltage, and keep preview and
archive work conservative.

## Capacity and Host Limits

VDisk Relay does not expand limits imposed by the USB host device. For example,
when the host is a Blink Sync Module 2, plan within that module's own camera and
local-storage limits. Use one relay image per independent host system.

The backing image should be sized for the host's expectations. VDisk Relay then
copies imported files into `DATA_ROOT`, usually `/files`, and the archive path
can move or duplicate that data elsewhere.

## Load Expectations

The Pi Zero W is the slowest supported target. The WebUI can become sluggish
while these tasks are active:

- mounting and syncing the image
- ffmpeg preview extraction
- Telegram uploads
- rsync archive transfers
- update/install runs
- NetworkManager recovery or emergency AP work

This is expected on low-power hardware. Keep debug features off unless needed,
lower preview generation rates, avoid heavy archive windows during active
recording periods, and use a Pi Zero 2 W or better for a smoother WebUI.

## Physical Checklist

Before enabling or validating live gates:

- the Pi boots from a stable power source
- `dtoverlay=dwc2` is configured
- `dwc2` and `libcomposite` are configured and loadable
- the Pi USB/OTG port is connected to the host device
- `/usbdisk.img` matches the `GADGET_MODPROBE_ARGS file=...` value
- the WebUI is reachable on the local network or emergency AP

After the gadget gate is active and `vdisk-relay-gadget-live.service` has
started, confirm that the host recognizes the virtual USB drive.
