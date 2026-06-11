# Network Emergency Checks

This specification defines concrete check values, thresholds and acceptance
tests for Network Emergency Mode.

## Default Check Values

| Value | Default | Meaning |
|---|---:|---|
| Check interval | 300 s | Guardian runs every 5 minutes. |
| Errors before AP | 3 | AP starts only after 3 consecutive local failures. |
| Reconnect wait time | 90 s | Wait time after an active Wi-Fi reconnect. |
| AP minimum runtime | 600 s | AP stays active for at least the first 10 minutes. |
| First recovery test | 600 s | 10-minute minimum, then a direct check in the next Guardian run. |
| UI heartbeat | 30 s | AP WebUI reports active operator use. |
| UI active window | 120 s | Delay recovery while the operator is active. |
| Recovery wait time | 90 s | Wait time after switching back to normal Wi-Fi. |
| Auto reboot | off | Prepared option, not active yet. |
| Auto-reboot cycles | 6 | Prepared threshold for a later escalation. |

## Local Network Check

A check is `OK` only when all required points are satisfied:

1. NetworkManager is active.
2. `nmcli` is available.
3. `wlan0` exists.
4. `wlan0` is connected.
5. An IPv4 address is available.
6. A default gateway is available.
7. The gateway is reachable.
8. DNS resolution works.

Recommended commands:

    nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status
    nmcli -g IP4.ADDRESS,IP4.GATEWAY device show wlan0
    ping -c 1 -W 2 <gateway>
    getent hosts example.com

`getent hosts` is only a DNS indicator. A failure there must not start the AP by
itself when the gateway and local network are healthy. In that case the state is
`degraded-internet`, not `local-network-down`.

## Failure Classes

`local-network-down`

- `wlan0` disconnected
- no IPv4 address
- no gateway
- gateway unreachable

Effect: increase the failure counter and prepare AP start after the threshold.

`dns-degraded`

- gateway reachable
- DNS resolution failed

Effect: warning state; throttle or pause external services, but do not start the
AP without another local failure.

`external-service-down`

- Git, Telegram or archive destination unreachable
- gateway and DNS are OK

Effect: no AP start. Only the affected services handle the error.

`networkmanager-missing`

- `nmcli` missing or NetworkManager not active

Effect: Guardian reports an error but does not start the AP, because AP control
itself is not safely available.

## AP Start Decision

Start AP when:

    local-network-down in 3 consecutive checks
    AND reconnect attempt failed
    AND NetworkManager can create an AP
    AND AP password is set

Do not start AP when:

    UI manually disabled AP
    Guardian gate missing
    AP password missing
    NetworkManager missing
    only external-service-down
    only dns-degraded with reachable gateway

## Recovery Test

Recovery test may start when:

    emergency_ap active
    AND now - ap_started_at >= 600
    AND no AP WebUI activity in the last 120 s

Recovery test flow:

1. Set state to `recovery_test`.
2. Stop the AP connection.
3. Connect the normal Wi-Fi profile or run `nmcli device connect wlan0`.
4. Wait 90 seconds.
5. Run the local network check.
6. On OK: state `normal`, failure counter 0, AP off.
7. On error: start AP again, state `emergency_ap`, start a new 10-minute minimum runtime.

## AP WebUI Activity

Heartbeat request:

    POST /emergency/heartbeat

Minimal payload:

    route=/wifi
    session_id=<random browser id>

State example:

    {
      "last_seen": "2026-06-05T12:00:00+02:00",
      "session_id": "b7d8...",
      "route": "/wifi"
    }

Active when:

    now - last_seen <= 120 seconds

When active:

- Delay recovery test.
- WebUI shows `Operator active`.

## Planned Auto-Reboot Check

Default: disabled. The following rules are prepared but not yet implemented in
the active Guardian path.

When enabled later, reboot only when:

    emergency_ap active
    AND failed_ap_cycles >= NETWORK_GUARDIAN_AUTO_REBOOT_AFTER_AP_CYCLES
    AND no AP WebUI activity
    AND AP minimum runtime expired
    AND /etc/vdisk-relay.allow-health-reboot exists

Before reboot, always write:

    echo "Network Guardian: ..." > /etc/restart.reason

## Status File

`/var/lib/vdisk-relay/network-guardian.json` should contain at least:

    {
      "state": "normal",
      "last_check_at": "2026-06-05T12:00:00+02:00",
      "last_ok_at": "2026-06-05T11:55:00+02:00",
      "failure_count": 0,
      "failure_class": "",
      "failure_reason": "",
      "active_connection": "Workshop WiFi",
      "gateway": "198.51.100.1",
      "ap_started_at": "",
      "failed_ap_cycles": 0,
      "next_action": "check",
      "next_action_not_before": "2026-06-05T12:05:00+02:00"
    }

## WebUI Display

Wi-Fi page should show:

- Guardian active/inactive
- state
- error class
- error reason
- last OK time
- last check
- next action
- AP SSID
- AP IP
- remaining AP minimum runtime
- recovery-test countdown
- operator active yes/no

## Acceptance Tests

### Normal State

Prerequisite:

    wlan0 connected, gateway reachable

Expected:

    state=normal
    failure_count=0
    AP off

### Broken Wi-Fi Profile

Prerequisite:

    wrong Wi-Fi password or profile disabled

Expected:

    after 3 checks plus reconnect attempt: emergency_ap
    AP SSID visible
    WebUI only Wi-Fi configuration

### Gateway Gone

Prerequisite:

    Wi-Fi connected, but gateway not pingable

Expected:

    local-network-down
    AP after threshold

### DNS Gone, Gateway OK

Prerequisite:

    gateway pingable, DNS broken

Expected:

    dns-degraded
    no AP start
    external services can be throttled

### AP Minimum Runtime

Prerequisite:

    emergency_ap just started

Expected:

    no recovery test before 10 minutes
    first automatic recovery test from the next Guardian run after 10 minutes

### AP WebUI Active

Prerequisite:

    emergency_ap active, browser open on /wifi?emergency=1

Expected:

    heartbeat every 30 seconds
    recovery test delayed
    auto reboot delayed

### Browser Closed

Prerequisite:

    AP WebUI was active, browser is closed

Expected:

    no activity after 120 seconds
    next due recovery test may run

### Captive Portal HTTP

Prerequisite:

    state=emergency_ap

Expected:

    curl -i http://10.254.77.1/generate_204
    -> HTTP 302 Location: /wifi?emergency=1&captive=1

    curl -i http://10.254.77.1/hotspot-detect.html
    -> HTTP 200 with link to /wifi?emergency=1

Normal operation:

    /generate_204 -> HTTP 204
    /hotspot-detect.html -> Success
    /connecttest.txt -> Microsoft Connect Test
    /ncsi.txt -> Microsoft NCSI

### Wi-Fi OK Again

Prerequisite:

    AP active, normal Wi-Fi reachable again

Expected:

    recovery test successful
    AP off
    state=normal
    failure_count=0

### External Services Broken

Prerequisite:

    gateway and DNS OK, but Git/Telegram/archive destination broken

Expected:

    no AP start
    error remains with the affected service

## Manual Test Helpers

Wi-Fi state:

    nmcli device status
    nmcli device show wlan0

Gateway test:

    ip route
    ping -c 1 -W 2 <gateway>

DNS test:

    getent hosts example.com

Check AP profile:

    nmcli connection show vdisk-relay-emergency-ap

Guardian state:

    cat /var/lib/vdisk-relay/network-guardian.json
    journalctl -u vdisk-relay-network-guardian.service -n 120 --no-pager
