# vdisk-relay prerequisites

## Short apt Install

    apt-get update
    apt-get install -y bash coreutils util-linux fdisk mount systemd rsync curl ca-certificates python3 grep sed gawk findutils procps kmod iproute2 inotify-tools dosfstools cron sudo git ffmpeg network-manager iputils-ping

## Target System

Tested on:

    Raspberry Pi Zero W
    Raspbian GNU/Linux 12 Bookworm
    armv6l kernel
    USB OTG gadget use

The Pi Zero W works, but UI responsiveness depends on system activity. A Pi
Zero 2 W or larger Raspberry Pi with separate power is recommended for smoother
WebUI use during sync, preview, Telegram, or archive work. See
[hardware.md](hardware.md) for wiring and power guidance.

## Package Dependencies

Packages:

    bash
    coreutils
    util-linux
    fdisk
    mount
    systemd
    rsync
    curl
    ca-certificates
    python3
    grep
    sed
    gawk
    findutils
    procps
    kmod
    iproute2
    inotify-tools
    dosfstools
    cron
    sudo
    git
    ffmpeg
    network-manager
    iputils-ping

Important commands:

    systemctl
    rsync
    curl
    python3
    losetup
    mount
    umount
    mountpoint
    findmnt
    flock
    timeout
    logger
    modprobe
    lsmod
    getent
    inotifywait
    fdisk
    mkfs.vfat
    dd
    reboot
    ffmpeg
    nmcli
    ping

## Kernel Modules

Required:

    dwc2
    libcomposite
    g_mass_storage

`g_mass_storage` is not loaded automatically through modules-load. Startup is
controlled through:

    vdisk-relay-gadget-live.service

## Raspberry Pi Boot Configuration

The boot configuration must contain:

    dtoverlay=dwc2

Possible files:

    /boot/firmware/config.txt
    /boot/config.txt

Recommended modules-load file:

    /etc/modules-load.d/vdisk-relay.conf

Contents:

    dwc2
    libcomposite

If `dtoverlay=dwc2` is added for the first time, reboot before expecting the USB
host to see the virtual drive. `modprobe dwc2` and `modprobe libcomposite` can
validate that modules are loadable, but the boot overlay is what makes OTG
gadget mode reliable on the target port.

## Image Formatting

The manual tool:

    /usr/local/bin/format-vdisk

is stored in the repository at:

    files/usr/local/bin/format-vdisk

It is destructive and intended only for manual maintenance/recovery.

## Check

Check only:

    deploy/bookworm/dependencies.sh --check

Install packages and set USB gadget boot configuration:

    deploy/bookworm/dependencies.sh --all
