# format-vdisk

`format-vdisk` is a manual maintenance and recovery tool for `/usbdisk.img`.

Purpose:

- reformat a broken or no longer cleanly readable `/usbdisk.img`
- restore the partition and FAT32 layout
- prepare the image for USB mass-storage use

Important:

- destructive
- do not run automatically
- not a systemd service
- use only as a deliberate manual action
- stop `g_mass_storage` first
- plan a reboot afterwards

Production path:

    /usr/local/bin/format-vdisk

In the repository:

    files/usr/local/bin/format-vdisk

Dependencies:

    fdisk
    losetup
    mkfs.vfat
    dd
    modprobe
    reboot
