# systemd Reference

This file is the repository reference for the installed `vdisk-relay` units.
Whether a unit is enabled on the target system depends on gates, WebUI
configuration and installer mode.

## Live Path

```text
vdisk-relay-gadget-live.service
vdisk-relay-watch-live.path
vdisk-relay-trigger-live.service
vdisk-relay-fast-sync.service
vdisk-relay-ultra-fast-sync.service
vdisk-relay-sync-live.service
vdisk-relay-retry-live.service
vdisk-relay-retry-live.timer
vdisk-relay-telegram-queue.service
vdisk-relay-telegram-queue.timer
vdisk-relay-image-mtime-watch.service
vdisk-relay-image-mtime-watch.timer
vdisk-relay-watchdog-live.service
vdisk-relay-watchdog-live.timer
```

## Maintenance And State

```text
vdisk-relay-archive-live.service
vdisk-relay-archive-live.timer
vdisk-relay-health-live.service
vdisk-relay-health-live.timer
vdisk-relay-boot-notify-live.service
vdisk-relay-status-cache.service
vdisk-relay-status-cache.timer
vdisk-relay-web-status-cache.service
vdisk-relay-web-status-cache.timer
vdisk-relay-debug-cache.service
vdisk-relay-debug-cache.timer
vdisk-relay-preview-cache.service
vdisk-relay-preview-cache.timer
vdisk-relay-network-guardian.service
vdisk-relay-network-guardian.timer
```

## Web And Update

```text
vdisk-relay-web.service
vdisk-relay-update.service
vdisk-relay-update-check.service
vdisk-relay-update-check.timer
```

## Manual Special Cases

```text
vdisk-relay-format-on-boot.service
```

## Timers

Check on the target system:

```bash
systemctl list-timers --all | grep vdisk-relay
```

Repository timers:

```text
vdisk-relay-archive-live.timer
vdisk-relay-health-live.timer
vdisk-relay-retry-live.timer
vdisk-relay-telegram-queue.timer
vdisk-relay-image-mtime-watch.timer
vdisk-relay-watchdog-live.timer
vdisk-relay-status-cache.timer
vdisk-relay-web-status-cache.timer
vdisk-relay-debug-cache.timer
vdisk-relay-preview-cache.timer
vdisk-relay-network-guardian.timer
vdisk-relay-update-check.timer
```

## Status Cache Ownership

`vdisk-relay-status-cache.service` is the only owner of the canonical status
cache under `/run/vdisk-relay/status.json` and `/run/vdisk-relay/status-login.txt`.
The `vdisk-relay status-lights` command reads that cache by default. Explicit
live diagnosis is available with `vdisk-relay status-lights --live`.

`vdisk-relay-debug-cache.service` writes debug output only and must not overwrite
the canonical status cache.

The status cache service exits `0` when it successfully builds and publishes a
complete cache, even if the represented system state is `WARN` or `FAIL`.
Consumers must read `overall.state` and `overall.exitcode` from `status.json`
instead of using the systemd result of `vdisk-relay-status-cache.service` as a
health signal.

Status component states are `OK`, `PENDING`, `WARN`, `FAIL`, `DISABLED`, and
`UNKNOWN`. `vdisk-relay status-lights` renders those states as `OK`, `PEND`,
`WARN`, `FAIL`, `OFF`, and `UNKN`.

After WebUI service actions, `/run/vdisk-relay/service-action-pending.json`
marks the affected unit as `PENDING`. The WebUI clears that transient state once
`status.json.generated_at` is newer than the action timestamp or the pending
window expires.

Fast-lane and ultra-fast-lane units are oneshot dispatchers. If their last run
failed while no pending state is open anymore, the canonical status treats that
as `WARN` instead of `FAIL`: the immediate attempt needs attention, but the
relay pipeline is no longer blocked. An open pending state plus a failed fast
dispatcher remains `FAIL`.
