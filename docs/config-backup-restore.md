# Config Backup / Restore

`vdisk-relay` can back up and restore its production configuration.

## Backup

    /usr/local/sbin/vdisk-relay config-backup

Default target:

    /root/vdisk-relay-config-backups/vdisk-relay-config-<host>-<timestamp>.tar.gz

The archive contains, when available:

    /etc/vdisk-relay.conf
    /etc/vdisk-relay.env
    /etc/vdisk-relay-maintenance-notify.json
    /root/vdisk-relay-rsync.pass
    configured ARCHIVE_RSYNC_PASSWORD_FILE, when different from /root/vdisk-relay-rsync.pass
    /var/lib/vdisk-relay/git-credentials.json
    /var/lib/vdisk-relay/last/
    /etc/NetworkManager/system-connections/
    /etc/vdisk-relay.live-enabled
    /etc/vdisk-relay.allow-*
    META/systemd-enabled.txt

Note: the backup contains secrets and must not be committed to Git.

Restore accepts only archives containing `etc/vdisk-relay.conf`. Old backups
from the earlier `video-vdisk` generation are not imported by the normal restore
path.

New config keys are filled with safe defaults automatically after a restore,
because `config-restore --apply` always runs `ensure_config_defaults` after
writing `/etc/vdisk-relay.conf`. Older vdisk-relay backups without newer options
therefore remain runnable.

The configuration for timeline debug, Telegram reply debug, Ultra Fast Lane and
the Ultra FIFO rest queue is backed up through `/etc/vdisk-relay.conf`. Runtime
diagnostic data itself is not backed up.

WebUI language files under `/usr/local/share/vdisk-relay/i18n/` are installation
files and are not backed up as configuration.

`META/systemd-enabled.txt` stores the enable/disable state of the vdisk-relay
units. Restore reapplies those states. If Git credentials are missing in the
restored state, the update-check timer remains disabled.

## Restore Dry Run

    /usr/local/sbin/vdisk-relay config-restore /root/vdisk-relay-config-backups/<backup>.tar.gz

Shows only the contents. Nothing is restored.

## Apply Restore

    /usr/local/sbin/vdisk-relay config-restore /root/vdisk-relay-config-backups/<backup>.tar.gz --apply

A new pre-restore backup is created automatically before the restore.

## Not Included

The following paths are not included:

    /usbdisk.img
    /files/
    /run/vdisk-relay/
    /run/vdisk-relay-www/
    /var/lib/vdisk-relay/ except git-credentials.json and last/
    /var/log/vdisk-relay.log
    /var/log/vdisk-relay-timeline.jsonl
