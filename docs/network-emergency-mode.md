# Network Emergency Mode

This specification describes the emergency mode for a permanently lost
local Wi-Fi/LAN connection. The goal is a resource-efficient AP mode that allows
Wi-Fi reconfiguration without making the Raspberry Pi Zero W busy-loop or switch
between modes at short intervals.

## Goal

When `wlan0` is no longer usable locally, `vdisk-relay` starts its own setup
access point after several failed checks. In AP mode, the WebUI is reduced to
Wi-Fi configuration. The system periodically checks whether the original Wi-Fi
works again. While an operator is actively using the AP WebUI, recovery tests and
optional reboots are delayed.

## Non-Goals

- No AP start when only Git, Telegram or the archive destination is unreachable.
- No aggressive roaming or permanent Wi-Fi scanning.
- No transparent HTTPS captive-portal redirect.
- No hard requirement for stable concurrent AP and client operation, because the
  Pi Zero W has a small single-radio Wi-Fi chipset.

## Components

Runtime component:

    /usr/local/sbin/vdisk-relay-network-guardian

Systemd units:

    vdisk-relay-network-guardian.service
    vdisk-relay-network-guardian.timer

Gate file:

    /etc/vdisk-relay.allow-network-guardian

State files:

    /var/lib/vdisk-relay/network-guardian.json
    /run/vdisk-relay/emergency-wifi-active.json
    /run/vdisk-relay/emergency-ui-active.json

NetworkManager profile for the emergency AP:

    vdisk-relay-emergency-ap

## Configuration

Defaults in `/etc/vdisk-relay.conf`:

    NETWORK_GUARDIAN_ENABLED="1"
    NETWORK_GUARDIAN_CHECK_INTERVAL_SECONDS="300"
    NETWORK_GUARDIAN_FAILS_BEFORE_AP="3"
    NETWORK_GUARDIAN_RECONNECT_WAIT_SECONDS="90"
    NETWORK_GUARDIAN_AP_MIN_SECONDS="600"
    NETWORK_GUARDIAN_UI_HEARTBEAT_SECONDS="30"
    NETWORK_GUARDIAN_UI_ACTIVE_GRACE_SECONDS="120"
    NETWORK_GUARDIAN_RECOVERY_WAIT_SECONDS="90"
    NETWORK_GUARDIAN_AUTO_REBOOT_ENABLED="0"
    NETWORK_GUARDIAN_AUTO_REBOOT_AFTER_AP_CYCLES="6"
    NETWORK_GUARDIAN_AP_SSID_PREFIX="VDiskRelay-Setup"
    NETWORK_GUARDIAN_AP_PASSWORD=""
    NETWORK_GUARDIAN_AP_IPV4="10.254.77.1/24"

`NETWORK_GUARDIAN_AP_PASSWORD` must be set through setup or the WebUI before the
AP can be used actively. The installer must not overwrite existing values.

## State Machine

`normal`

The system is on regular Wi-Fi. Guardian runs only lightweight checks. Failure
counters are reset after a successful local network check.

`suspect`

One or more local network checks have failed. The failure counter is increased
after each error. Exactly one reconnect attempt is started before switching into
AP mode.

`emergency_ap`

The emergency AP is active. The WebUI permits only Wi-Fi configuration,
emergency state and captive-portal endpoints. All other routes redirect to
`/wifi?emergency=1`.

`recovery_test`

The AP is stopped briefly, the original Wi-Fi is enabled again and checked after
a wait time. On success the system goes to `normal`; on error it returns to
`emergency_ap`.

`manual_hold`

An operator explicitly keeps the AP open or is active on the AP WebUI. Guardian
delays recovery test and optional reboot.

## AP Timing Logic

After AP start, `ap_started_at` is stored.

- Minutes 0 to 10: AP always stays active.
- Afterwards, the next Guardian run directly checks whether normal Wi-Fi works again.
- First automatic recovery test no earlier than after 10 minutes of AP runtime.
- If the AP WebUI is actively used, the recovery test is delayed further.

Activity is detected through a lightweight heartbeat:

    POST /emergency/heartbeat

In AP mode, the WebUI sends the heartbeat every 30 seconds. The server writes
`/run/vdisk-relay/emergency-ui-active.json`. If `last_seen` is newer than
`NETWORK_GUARDIAN_UI_ACTIVE_GRACE_SECONDS`, recovery test and auto reboot are
blocked.

## Start Conditions For Emergency AP

AP mode starts only on local network loss:

- `wlan0` not connected
- no IPv4 address
- no default gateway
- gateway unreachable
- DNS resolution fails although the system otherwise appears locally connected

After `NETWORK_GUARDIAN_FAILS_BEFORE_AP` consecutive failed checks:

1. Run a reconnect attempt for the active Wi-Fi profile.
2. Wait `NETWORK_GUARDIAN_RECONNECT_WAIT_SECONDS`.
3. Repeat checks.
4. Start AP mode only on another error.

No AP start for:

- Git unreachable
- Telegram unreachable
- archive destination unreachable
- external internet broken, but gateway and local LAN OK

## AP Mode

NetworkManager should manage the AP. This keeps the implementation close to the
existing Wi-Fi WebUI and avoids parallel special paths for `hostapd`, provided
NetworkManager supports AP mode cleanly on the target system.

AP profile shape:

    connection.id vdisk-relay-emergency-ap
    connection.autoconnect no
    802-11-wireless.mode ap
    802-11-wireless.ssid <Prefix>-<Host-Suffix>
    ipv4.method shared
    ipv4.addresses 10.254.77.1/24
    ipv6.method disabled

If `ipv4.method shared` does not provide usable captive-portal DNS on the target
system, Phase 5 adds a small dnsmasq configuration.

## WebUI In Emergency Mode

Allowed routes:

    /wifi
    /wifi/*
    /emergency/*
    /generate_204
    /gen_204
    /hotspot-detect.html
    /connecttest.txt
    /ncsi.txt
    /manifest.webmanifest
    /favicon.svg
    /app-icon-192.png
    /app-icon-512.png
    /sw.js

All other routes:

    302 -> /wifi?emergency=1

In emergency mode, the Wi-Fi page shows only:

- emergency status
- AP SSID and AP IP
- error reason
- last check
- next possible recovery test
- create/edit Wi-Fi profiles
- IP settings
- button `Test normal mode now`
- button `Keep AP active`
- optional button `End emergency mode`

## Captive Portal

HTTP captive-portal endpoints:

    /generate_204
    /gen_204
    /hotspot-detect.html
    /connecttest.txt
    /ncsi.txt

These endpoints should return a simple HTML response or redirect to
`/wifi?emergency=1`. HTTPS is not transparently redirected. In normal operation,
the endpoints return the expected standard responses so clients do not show a
captive portal.

## Planned Reboot Escalation

Auto reboot defaults to off and is currently only prepared as a configuration
option. The active Guardian logic does not yet run automatic reboots. If the
escalation is enabled later, these rules apply:

- only after multiple unsuccessful AP recovery cycles
- never during active AP WebUI use
- never during the first 10 minutes of AP minimum runtime
- always with `/etc/restart.reason`
- state and countdown visible in the WebUI

Example reason:

    Network Guardian: auto reboot after 6 unsuccessful AP recovery cycles

## Implementation State

This section records implementation state. It is not an operator runbook.

### Phase 1: Status Base

State: implemented.

- Add config defaults.
- Define state file.
- WebUI shows Guardian state.
- No AP switching yet.
- Backup/restore automatically includes new config values.

### Phase 2: Guardian Service

State: implemented. The service writes `/var/lib/vdisk-relay/network-guardian.json`
and runs local checks and reconnect attempts.

- Implement `vdisk-relay-network-guardian`.
- Add systemd service and timer.
- Lightweight local checks every 5 minutes.
- Failure counter and reconnect attempt.
- No captive portal yet.

### Phase 3: AP Cycle

State: implemented. On local network loss, Guardian starts a NetworkManager AP,
keeps it active for at least 10 minutes and then directly tests normal Wi-Fi.

- Create/update NetworkManager AP profile.
- Start/stop AP.
- 10-minute minimum runtime.
- Direct recovery test in the next Guardian run afterwards.
- Recovery test with normal Wi-Fi.
- Return to `normal` on success.

### Phase 4: WebUI Lockdown And Heartbeat

State: implemented. The WebUI limits active emergency sessions to Wi-Fi and
emergency endpoints and writes heartbeats to
`/run/vdisk-relay/emergency-ui-active.json`.

- Emergency WebUI mode.
- Route lockdown to Wi-Fi configuration.
- `/emergency/heartbeat`.
- AP activity delays recovery test and auto reboot.

### Phase 5: Captive Portal

State: HTTP endpoints implemented. DNS hijack/dnsmasq remains optional and is
enabled only after an AP test on the target device if NetworkManager
`ipv4.method shared` does not route captive-portal checks to the Pi.

- Captive-portal endpoints.
- Optional dnsmasq if NetworkManager shared DNS is not enough.
- Check mobile UX for Android Chrome installation flow.

### Phase 6: Reboot Escalation And Operations

State: partially implemented. Auto reboot remains prepared but inactive; the
operations UI already exposes the Guardian settings and AP hold action.

- Implement optional auto reboot.
- Show journal/log in maintenance area.
- Manual buttons for `Test normal mode now`, `Hold AP`, `End emergency`.
- Activate the Guardian timer automatically only when NetworkManager is available.

## Remaining Decisions

- Auto-generate AP passwords or keep the current manual password flow.
- Keep auto reboot permanently off by default or enable it later after field validation.
- Add dnsmasq only if NetworkManager shared DNS is insufficient on target hardware.
