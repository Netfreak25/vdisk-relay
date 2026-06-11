# Configuration Reference

Primary file:

```text
/etc/vdisk-relay.conf
```

Secrets are not stored in this file. Telegram tokens and chat IDs live in:

```text
/etc/vdisk-relay.env
```

The rsync-daemon password normally lives in:

```text
/root/vdisk-relay-rsync.pass
```

Values are shell assignments. Use quotes for values that contain spaces:

```bash
DATA_ROOT="/files"
ARCHIVE_RSYNC_TARGET="rsync@archive.example::module/path/"
```

## Core Paths

| Variable | Default | Description |
|---|---|---|
| `IMAGE_FILE` | `/usbdisk.img` | Backing image exposed through USB mass storage. |
| `MOUNTPOINT` | `/run/vdisk-relay/mnt` | Read-only shadow mount point. |
| `DATA_ROOT` | `/files` | Local data directory used by the WebUI, sync, archive, and preview cache. |
| `STATE_DIR` | `/var/lib/vdisk-relay` | Persistent state directory. |
| `RUN_DIR` | `/run/vdisk-relay` | Runtime directory for locks and temporary state. |
| `LOG_FILE` | `/var/log/vdisk-relay.log` | Main log file. |

## Image and Mount

| Variable | Default | Description |
|---|---|---|
| `PARTITION_OFFSET_SECTORS` | `2048` | Partition offset used for the image mount. |
| `MOUNT_FSTYPE` | `vfat` | Filesystem type used for the image mount. |
| `GADGET_MODPROBE_ARGS` | `file=/usbdisk.img ...` | Arguments for `g_mass_storage`. Keep `file=` aligned with `IMAGE_FILE`. |

## Watch, Sync, and Fast Lane

| Variable | Default | Description |
|---|---|---|
| `WATCH_EVENT` | `modify` | Event used by the watch path. |
| `WATCH_DEBOUNCE_SECONDS` | `2` | Small debounce for direct watch mode. |
| `LIVE_QUIET_SECONDS` | `8` | Normal quiet check before live sync. |
| `LIVE_FAST_LANE_ENABLED` | `1` | Enables the early Fast Lane service after a trigger. |
| `LIVE_FAST_LANE_DELAY_SECONDS` | `3` | Delay before Fast Lane attempts `live-sync --fast`. |
| `LIVE_FAST_QUIET_SECONDS` | `3` | Quiet check used by Fast Lane. |
| `SYNC_RSYNC_OPTIONS` | `-r --ignore-existing` | rsync options for real sync from image to `DATA_ROOT`. |
| `SYNC_RSYNC_DRYRUN_OPTIONS` | `-n --ignore-existing --stats` | rsync options for dry-run paths. |
| `SYNC_PASSES` | `0.5 4 10` | Historical multi-pass timing value, kept for compatibility. |

## Ultra Fast Lane

| Variable | Default | Description |
|---|---|---|
| `ULTRA_FAST_LANE_ENABLED` | `0` | Enables direct send from the read-only shadow mount. Default is off. |
| `ULTRA_FAST_LANE_DELAY_SECONDS` | `0` | Optional delay before the first Ultra send. |
| `ULTRA_FAST_LANE_QUIET_SECONDS` | `0` | Optional quiet check for Ultra. |
| `ULTRA_FAST_LANE_SYNC_AFTER_SEND` | `1` | Syncs image content to `DATA_ROOT` after successful Ultra send. |
| `ULTRA_FAST_DUPLICATE_MODE` | `filename` | Duplicate mode: `filename`, `strict`, or `off`. |
| `ULTRA_FAST_REMAINDER_QUEUE_ENABLED` | `1` | Sends additional new Ultra candidates FIFO. |
| `ULTRA_FAST_REMAINDER_QUEUE_DELAY_SECONDS` | `2` | Delay between additional Ultra sends. |

Example low-latency test mode:

```bash
ULTRA_FAST_LANE_ENABLED="1"
ULTRA_FAST_DUPLICATE_MODE="filename"
ULTRA_FAST_REMAINDER_QUEUE_ENABLED="1"
ULTRA_FAST_REMAINDER_QUEUE_DELAY_SECONDS="2"
```

## Telegram queue

| Variable | Default | Description |
|---|---|---|
| `TELEGRAM_QUEUE_ENABLED` | `1` | Enables persistent queue for the normal delivery path. |
| `TELEGRAM_QUEUE_RETRY_SECONDS` | `60` | Delay before retrying failed queue jobs. |
| `TELEGRAM_QUEUE_MAX_ATTEMPTS` | `30` | Maximum attempts per queue job. |
| `TELEGRAM_QUEUE_PROCESS_LIMIT` | `2` | Jobs processed per worker run. |
| `TELEGRAM_QUEUE_DONE_MAX_FILES` | `200` | Retained done-job metadata files. |
| `CURL_MAX_TIME` | `120` | Default curl max time for Telegram uploads. |

## Debug and Timeline

All debug features are off by default.

| Variable | Default | Description |
|---|---|---|
| `TIMELINE_TRACE_ENABLED` | `0` | Enables JSONL timeline tracing. |
| `TIMELINE_TRACE_FILE` | `/var/log/vdisk-relay-timeline.jsonl` | Timeline trace file. |
| `TIMELINE_TRACE_SYSTEM_SNAPSHOT` | `0` | Adds light system snapshots to trace events. |
| `TELEGRAM_TRACE_REPLY_BODY` | `0` | Stores Telegram reply bodies when timeline tracing is enabled. |
| `TELEGRAM_TRACE_REPLY_MAX_BYTES` | `20000` | Maximum stored Telegram reply bytes. |

## Sources

`SOURCES` defines all active data sources.

Format:

```text
id|enabled|profile|label|match|extensions|telegram_mode|time_mode|source_timezone|display_timezone|last_file|bot_var|chat_var|retries|wait_seconds|tmp_log
```

Example:

```bash
SOURCES=(
  "frontdoor|1|blink-security-video|Front Door|Front|mp4|video|blink-utc|UTC|Europe/Berlin|/var/lib/vdisk-relay/last/frontdoor.last|PRIMARY_BOT_TOKEN|PRIMARY_CHAT_ID|4|3|/run/vdisk-relay/frontdoor.telegram.log"
)
```

Fields:

| Field | Description |
|---|---|
| `id` | Stable source ID, used for state files. |
| `enabled` | `1` enabled, `0` disabled. |
| `profile` | Source profile, for example `blink-security-video` or `generic-media-drop`. |
| `label` | Human label shown in the WebUI. |
| `match` | Filename match string. Use `*` for all files. |
| `extensions` | Comma-separated extensions, or `*`. |
| `telegram_mode` | `video`, `photo`, `audio`, `document`, or `auto`. |
| `time_mode` | `blink-utc` or `mtime`. |
| `source_timezone` | Timezone metadata for source timestamps. |
| `display_timezone` | Legacy per-source display timezone metadata. Current Media/Data rendering uses `WEB_DISPLAY_TIMEZONE`. |
| `last_file` | Per-source send-state file. |
| `bot_var` | Env variable name in `/etc/vdisk-relay.env`. |
| `chat_var` | Env variable name in `/etc/vdisk-relay.env`. |
| `retries` | Telegram retries for direct test sends. |
| `wait_seconds` | Delay between direct test-send retries. |
| `tmp_log` | Per-source temporary Telegram log path. |

Defaults used by the WebUI/wizard:

| Variable | Default | Description |
|---|---|---|
| `SOURCE_DEFAULT_RETRIES` | `4` | Default source retry count. |
| `SOURCE_DEFAULT_WAIT_SECONDS` | `3` | Default retry wait. |
| `SOURCE_LAST_STATE_DIR` | `/var/lib/vdisk-relay/last` | Send-state directory. |
| `SOURCE_TMP_LOG_DIR` | `/run/vdisk-relay` | Temporary Telegram log directory. |
| `SOURCE_DEFAULT_EXTENSION` | `mp4` | Default extension for new sources. |

## Archive

| Variable | Default | Description |
|---|---|---|
| `ARCHIVE_RSYNC_TARGET` | empty | rsync-daemon target, for example `rsync@host::module/path/`. |
| `ARCHIVE_RSYNC_PASSWORD_FILE` | `/root/vdisk-relay-rsync.pass` | rsync-daemon password file. |
| `ARCHIVE_RSYNC_MAX_SECONDS` | `900` | Maximum archive run time. |
| `ARCHIVE_RSYNC_CONTIMEOUT` | `10` | rsync connect timeout. |
| `ARCHIVE_RSYNC_TIMEOUT` | `60` | rsync I/O timeout. |

## Health and Maintenance

| Variable | Default | Description |
|---|---|---|
| `MAX_DATA_AGE_SECONDS` | `100800` | Maximum accepted age of newest active file. |
| `IMAGE_STALE_SECONDS` | `900` | Image stale threshold for maintenance detection. |
| `IMAGE_STALE_REBOOT_COOLDOWN_SECONDS` | `3600` | Cooldown for reboot escalation. |

## Preview Cache

| Variable | Default | Description |
|---|---|---|
| `PREVIEW_NEW_PER_RUN` | `3` | New previews generated per service run. |
| `PREVIEW_FFMPEG_TIMEOUT` | `180` | Timeout for attempt 1 and 2. |
| `PREVIEW_LONG_FFMPEG_TIMEOUT` | `600` | Timeout from attempt 3. |
| `PREVIEW_SCAN_MAX_FILES` | `5000` | Maximum files scanned into `files.json`. |
| `PREVIEW_CACHE_MAX_FILES` | `5000` | Maximum preview files retained. |
| `PREVIEW_OFFSET_SECONDS` | `1` | Frame offset for normal video previews. |
| `PREVIEW_SMALL_VIDEO_BYTES` | `153600` | Small videos at or below this size use the second frame. |
| `PREVIEW_ATTEMPTS_PER_RUN` | `4` | Maximum preview attempts per run. |

## WebUI

| Variable | Default | Description |
|---|---|---|
| `WEB_DISPLAY_TIMEZONE` | `Europe/Berlin` | IANA timezone used for Media/Data timestamps, date grouping, and filtering. |
| `WEB_SCREENSAVER_IDLE_MINUTES` | `0` | Desktop screensaver idle time. `0` disables it. |
| `WEB_SCREENSAVER_MODE` | `floating` | Screensaver mode. |
| `DELETE_PREVIEW_WITH_VIDEO` | `0` | If enabled, deleting recordings from Data UI also deletes their preview thumbnail and preview index entries. |

Media/Data display times are re-derived from UTC-like filenames or file mtimes
using `WEB_DISPLAY_TIMEZONE`. Preformatted values in the preview catalog are not
treated as authoritative for timezone display.
The per-source `display_timezone` field remains part of `SOURCES` for
compatibility and source metadata, but it does not override the global WebUI
Media/Data display timezone.

The status cache only evaluates Data freshness through `vdisk-relay health`.
The Data WebUI remains responsible for display timezone conversion, day
grouping, and date filtering from the cached `files.json` entries.

## Network Guardian

| Variable | Default | Description |
|---|---|---|
| `NETWORK_GUARDIAN_ENABLED` | `1` | Enables guardian logic in config. Gate still controls activation. |
| `NETWORK_GUARDIAN_CHECK_INTERVAL_SECONDS` | `300` | Check interval. |
| `NETWORK_GUARDIAN_FAILS_BEFORE_AP` | `3` | Local network failures before AP mode. |
| `NETWORK_GUARDIAN_RECONNECT_WAIT_SECONDS` | `90` | Wait after reconnect action. |
| `NETWORK_GUARDIAN_AP_MIN_SECONDS` | `600` | AP minimum runtime before recovery checks. |
| `NETWORK_GUARDIAN_UI_HEARTBEAT_SECONDS` | `30` | AP WebUI heartbeat interval. |
| `NETWORK_GUARDIAN_UI_ACTIVE_GRACE_SECONDS` | `120` | Keeps AP active while a user is active. |
| `NETWORK_GUARDIAN_RECOVERY_WAIT_SECONDS` | `90` | Wait after returning to normal Wi-Fi. |
| `NETWORK_GUARDIAN_AUTO_REBOOT_ENABLED` | `0` | Reserved reboot escalation switch. |
| `NETWORK_GUARDIAN_AUTO_REBOOT_AFTER_AP_CYCLES` | `6` | Reserved reboot escalation threshold. |
| `NETWORK_GUARDIAN_AP_SSID_PREFIX` | `VDiskRelay-Setup` | Emergency AP SSID prefix. |
| `NETWORK_GUARDIAN_AP_PASSWORD` | empty | Emergency AP password. |
| `NETWORK_GUARDIAN_AP_IPV4` | `10.254.77.1/24` | Emergency AP IPv4 address. |
