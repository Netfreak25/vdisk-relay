# Secrets

Not included in the repository:

- `/etc/vdisk-relay.env`
  - Telegram bot tokens
  - Telegram chat IDs
  - permissions: `0600 root:root`

- `/root/vdisk-relay-rsync.pass`
  - password for the rsync daemon
  - permissions: `0600 root:root`

- `/var/lib/vdisk-relay/git-credentials.json`
  - Git username and personal access token for web updates
  - permissions: `0600 root:root`
