# Troubleshooting

Use this page for field symptoms before changing configuration. Commands are
read-only unless noted.

## Host Does Not See the USB Drive

Likely causes:

- Pi is connected through the power-only port instead of the USB/OTG port
- cable or adapter carries power only, not data
- `dwc2` boot configuration is missing
- `g_mass_storage` is not loaded
- `GADGET_MODPROBE_ARGS file=...` points to the wrong image
- the backing image is missing or corrupt

Checks:

```bash
lsmod | grep -E 'dwc2|libcomposite|g_mass_storage'
systemctl status vdisk-relay-gadget-live.service --no-pager
/usr/local/sbin/vdisk-relay status-lights
ls -lh /usbdisk.img
```

Fix direction:

- run `deploy/bookworm/dependencies.sh --configure-gadget`
- reconnect to the Pi USB/OTG port
- replace charge-only adapters with data-capable adapters
- verify `IMAGE_FILE` and `GADGET_MODPROBE_ARGS`

## WebUI Is Slow or Temporarily Unavailable

This can be normal on a Pi Zero W during heavy work. Common causes:

- image sync is active
- ffmpeg preview extraction is running
- Telegram uploads are in progress
- archive rsync is transferring data
- update/install restarted the WebUI service
- Wi-Fi recovery or emergency AP mode is active

Checks:

```bash
systemctl list-timers --all | grep vdisk-relay
systemctl --failed
tail -n 120 /var/log/vdisk-relay.log
```

Mitigation:

- use separate Pi power and avoid undervoltage
- lower preview generation rates
- avoid archive runs during busy recording windows
- keep timeline and Telegram reply-body tracing disabled by default
- use Pi Zero 2 W or better for smoother WebUI response

## Status Cache Looks Inconsistent

`vdisk-relay-status-cache.service` only reports whether the canonical status
cache was built. Do not treat that unit's systemd state as the system health
signal. Use:

```bash
/usr/local/sbin/vdisk-relay status-lights
cat /run/vdisk-relay/status.json
cat /run/vdisk-relay/status-last-attempt.json
```

`status-lights` is cache-based by default. Use `status-lights --live` only for
manual diagnosis. If the WebUI Services page shows `PENDING` after a service
action, the action was accepted and the status cache is being rebuilt. The state
clears automatically after a newer `status.json` is available.

Ultra Fast Lane can legitimately find no new candidate on a stale or duplicate
pending event. In that case it keeps pending for the normal fallback path and
exits successfully, so systemd does not preserve a false failed state.

## Files Are Not Imported to `/files`

Likely causes:

- live gates are missing
- host has not written a complete file yet
- watch/trigger did not fire
- image is stale or mounted elsewhere
- `DATA_ROOT` is wrong or full
- source filters do not match the file names

Checks:

```bash
/usr/local/sbin/vdisk-relay status-lights
systemctl status vdisk-relay-watch-live.path --no-pager
systemctl status vdisk-relay-retry-live.timer --no-pager
df -h /files
find /files -type f | tail -n 20
```

## Preview Cache Is Empty or Old

Likely causes:

- preview cache timer/service has not run yet
- ffmpeg failed on a file
- scan limit is too small
- files are outside `DATA_ROOT`
- Pi Zero W is busy and preview work is slow

Checks:

```bash
systemctl status vdisk-relay-preview-cache.timer --no-pager
systemctl status vdisk-relay-preview-cache.service --no-pager
ls -lh /var/cache/vdisk-relay-previews/
tail -n 120 /var/log/vdisk-relay.log
```

Tune with `PREVIEW_NEW_PER_RUN`, `PREVIEW_SCAN_MAX_FILES`,
`PREVIEW_CACHE_MAX_FILES`, and timeout values in `/etc/vdisk-relay.conf`.

## Telegram Does Not Send

Likely causes:

- bot token or chat ID is missing
- source is not assigned to a bot/chat
- queue worker is disabled or failing
- network is down
- file type does not match the selected Telegram mode

Checks:

```bash
/usr/local/sbin/vdisk-relay status-lights
systemctl status vdisk-relay-telegram-queue.timer --no-pager
find /var/lib/vdisk-relay/telegram-queue -maxdepth 2 -type f | head
tail -n 120 /var/log/vdisk-relay.log
```

The WebUI Telegram debug page intentionally shows a small filtered log excerpt.
It does not display per-source temporary Telegram response files. Use explicit
timeline reply-body tracing only when deeper Telegram diagnostics are needed.

## Archive Does Not Run

Likely causes:

- archive gate is disabled
- rsync destination or password file is missing
- remote archive endpoint is unreachable
- transfer timeout is too low

Checks:

```bash
systemctl status vdisk-relay-archive-live.timer --no-pager
ls -l /root/vdisk-relay-rsync.pass
tail -n 120 /var/log/vdisk-relay.log
```

## Emergency AP or Wi-Fi Recovery Is Active

Network Guardian can intentionally keep the emergency AP active while local
network recovery is being tested. Check:

```bash
cat /var/lib/vdisk-relay/network-guardian.json
systemctl status vdisk-relay-network-guardian.timer --no-pager
```

See [network-emergency-mode.md](network-emergency-mode.md) and
[network-emergency-checks.md](network-emergency-checks.md).

## Collect a Minimal Debug Snapshot

When reporting a problem, collect:

```bash
/usr/local/sbin/vdisk-relay status-lights
systemctl --failed
systemctl list-timers --all | grep vdisk-relay
tail -n 160 /var/log/vdisk-relay.log
```

Do not paste real tokens, chat IDs, hostnames, private IP addresses, archive
targets, or password file contents into public issues or commits.
