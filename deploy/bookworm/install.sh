#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LIVE_MODE=auto
FORCE_CONFIG=0
INSTALL_MOTD=1
INSTALL_WEB=1
RESTART_ACTIVE=1
AUTO_PULL=1
SYSTEMCTL_JOB_TIMEOUT="${VDISK_RELAY_INSTALL_SYSTEMCTL_TIMEOUT:-8s}"
INSTALL_DATA_ROOT="/files"
INSTALL_MAX_DATA_AGE_SECONDS="100800"
INSTALL_SOURCE_DEFAULT_RETRIES="4"
INSTALL_SOURCE_DEFAULT_WAIT_SECONDS="3"
INSTALL_SOURCE_LAST_STATE_DIR="/var/lib/vdisk-relay/last"
INSTALL_SOURCE_TMP_LOG_DIR="/run/vdisk-relay"
INSTALL_SOURCE_DEFAULT_EXTENSION="mp4"
INSTALL_PREVIEW_NEW_PER_RUN="3"
INSTALL_PREVIEW_FFMPEG_TIMEOUT="180"
INSTALL_PREVIEW_LONG_FFMPEG_TIMEOUT="600"
INSTALL_PREVIEW_SCAN_MAX_FILES="5000"
INSTALL_PREVIEW_CACHE_MAX_FILES="5000"
INSTALL_PREVIEW_OFFSET_SECONDS="1"
INSTALL_PREVIEW_SMALL_VIDEO_BYTES="153600"
INSTALL_PREVIEW_ATTEMPTS_PER_RUN="4"
INSTALL_SCREEN_SAVER_IDLE_MINUTES="0"
INSTALL_SCREEN_SAVER_MODE="floating"
INSTALL_LIVE_FAST_LANE_ENABLED="1"
INSTALL_LIVE_FAST_LANE_DELAY_SECONDS="3"
INSTALL_LIVE_FAST_QUIET_SECONDS="3"
INSTALL_TIMELINE_TRACE_ENABLED="0"
INSTALL_TIMELINE_TRACE_FILE="/var/log/vdisk-relay-timeline.jsonl"
INSTALL_TIMELINE_TRACE_SYSTEM_SNAPSHOT="0"
INSTALL_TELEGRAM_TRACE_REPLY_BODY="0"
INSTALL_TELEGRAM_TRACE_REPLY_MAX_BYTES="20000"
INSTALL_DELETE_PREVIEW_WITH_VIDEO="0"
INSTALL_ULTRA_FAST_LANE_ENABLED="0"
INSTALL_ULTRA_FAST_LANE_DELAY_SECONDS="0"
INSTALL_ULTRA_FAST_LANE_QUIET_SECONDS="0"
INSTALL_ULTRA_FAST_LANE_SYNC_AFTER_SEND="1"
INSTALL_ULTRA_FAST_DUPLICATE_MODE="filename"
INSTALL_ULTRA_FAST_REMAINDER_QUEUE_ENABLED="1"
INSTALL_ULTRA_FAST_REMAINDER_QUEUE_DELAY_SECONDS="2"
INSTALL_TELEGRAM_QUEUE_ENABLED="1"
INSTALL_TELEGRAM_QUEUE_RETRY_SECONDS="60"
INSTALL_TELEGRAM_QUEUE_MAX_ATTEMPTS="30"
INSTALL_TELEGRAM_QUEUE_PROCESS_LIMIT="2"
INSTALL_TELEGRAM_QUEUE_DONE_MAX_FILES="200"
INSTALL_NETWORK_GUARDIAN_ENABLED="1"
INSTALL_NETWORK_GUARDIAN_CHECK_INTERVAL_SECONDS="300"
INSTALL_NETWORK_GUARDIAN_FAILS_BEFORE_AP="3"
INSTALL_NETWORK_GUARDIAN_RECONNECT_WAIT_SECONDS="90"
INSTALL_NETWORK_GUARDIAN_AP_MIN_SECONDS="600"
INSTALL_NETWORK_GUARDIAN_UI_HEARTBEAT_SECONDS="30"
INSTALL_NETWORK_GUARDIAN_UI_ACTIVE_GRACE_SECONDS="120"
INSTALL_NETWORK_GUARDIAN_RECOVERY_WAIT_SECONDS="90"
INSTALL_NETWORK_GUARDIAN_AUTO_REBOOT_ENABLED="0"
INSTALL_NETWORK_GUARDIAN_AUTO_REBOOT_AFTER_AP_CYCLES="6"
INSTALL_NETWORK_GUARDIAN_AP_SSID_PREFIX="VDiskRelay-Setup"
INSTALL_NETWORK_GUARDIAN_AP_PASSWORD=""
INSTALL_NETWORK_GUARDIAN_AP_IPV4="10.254.77.1/24"

OBSOLETE_SYSTEMD_UNITS=(
  vdisk-relay-status.service
  vdisk-relay-status.timer
  vdisk-relay-status-boot.timer
  vdisk-relay-watch-shadow.service
  vdisk-relay-retry-shadow.service
  vdisk-relay-retry-shadow.timer
  vdisk-relay-health-shadow.service
  vdisk-relay-health-shadow.timer
)

OBSOLETE_SYSTEMD_PATHS=(
  /etc/systemd/system/vdisk-relay-status.service
  /etc/systemd/system/vdisk-relay-status.timer
  /etc/systemd/system/vdisk-relay-status-boot.timer
  /etc/systemd/system/vdisk-relay-status.service.d/permissions.conf
  /etc/systemd/system/vdisk-relay-web-status-cache.service.d/detail-link.conf
  /etc/systemd/system/vdisk-relay-watch-shadow.service
  /etc/systemd/system/vdisk-relay-retry-shadow.service
  /etc/systemd/system/vdisk-relay-retry-shadow.timer
  /etc/systemd/system/vdisk-relay-health-shadow.service
  /etc/systemd/system/vdisk-relay-health-shadow.timer
)

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage: $0 [OPTIONS]

Installs vdisk-relay files from the repository onto a target system.

Options:
  --no-live         suppress initial live activation, only install/update
  --force-live      reset live gates and deliberately enable live services
  --enable-live     deprecated alias for --force-live
  --force-config    overwrite /etc/vdisk-relay.conf and create a backup
  --no-motd         do not install MOTD file
  --no-web          do not install/enable web status service
  --no-restart      do not restart already active update services
  --no-pull         do not update the Git checkout before installation
  -h, --help        show help

Default:
  Files and systemd units are installed.
  Secrets are not overwritten.
  A Git checkout is updated with git pull --ff-only.
  Already active web/status services are updated.
  If no gate state exists yet and the required configuration is complete,
  production runtime is enabled automatically for the first time.
  Existing gates remain unchanged. A manually removed
  gate file, for example allow-archive, is not recreated.

Gate and live-mode details:
  Gates are simple allow files under /etc. systemd units start only
  when their ConditionPathExists gates are present.
  Sets /etc/vdisk-relay.live-enabled and the allow-* gate files for
  gadget, watch, trigger, sync, archive, health reboot, and boot notify.
  During automatic initial activation these default gates are set exactly once.
  Afterwards, existing gate decisions are preserved by updates.
  --force-live deliberately resets the default gates and can re-enable
  manually removed gates.
  Live mode enables and starts units for USB gadget, file watch, retry sync,
  archive, health watchdog, status cache, web cache, debug cache, preview cache,
  and WebUI. Boot notify is enabled for the next boot, but not run immediately.
  The update-check timer is enabled when the WebUI updater is installed.
  If required configuration is missing, runtime services are paused and only
  WebUI/wizard remains active.

Examples:
  $0 --help
  $0
  $0 --no-live
  $0 --force-live --no-pull
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-live) LIVE_MODE=skip ;;
    --force-live) LIVE_MODE=force ;;
    --enable-live)
      LIVE_MODE=force
      warn "--enable-live is deprecated; use --force-live"
      ;;
    --force-config) FORCE_CONFIG=1 ;;
    --no-motd) INSTALL_MOTD=0 ;;
    --no-web) INSTALL_WEB=0 ;;
    --no-restart) RESTART_ACTIVE=0 ;;
    --no-pull) AUTO_PULL=0 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

[ "$(id -u)" -eq 0 ] || fail "This install script must run as root"
[ -d "$REPO_ROOT/files" ] || fail "Repository file layout missing: $REPO_ROOT/files"
command -v systemctl >/dev/null 2>&1 || fail "systemctl missing"
command -v rsync >/dev/null 2>&1 || warn "rsync missing; archive function will not run"
command -v curl >/dev/null 2>&1 || warn "curl missing; Telegram functions will not run"
command -v python3 >/dev/null 2>&1 || warn "python3 missing; web status service will not run"
command -v ffmpeg >/dev/null 2>&1 || warn "ffmpeg missing; preview cache will not run"
command -v nmcli >/dev/null 2>&1 || warn "nmcli missing; Wi-Fi WebUI and Network Guardian are limited"
command -v ping >/dev/null 2>&1 || warn "ping missing; network checks are limited"

  ok "Repository detected: $REPO_ROOT"


git_repo_owner() {
  stat -c '%U' "$REPO_ROOT" 2>/dev/null || true
}

git_repo_cmd() {
  local owner
  owner="$(git_repo_owner)"

  if [ -n "$owner" ] && [ "$owner" != "root" ] && [ "$owner" != "UNKNOWN" ] && command -v sudo >/dev/null 2>&1; then
    sudo -H -u "$owner" git -C "$REPO_ROOT" "$@"
  else
    git -c "safe.directory=$REPO_ROOT" -C "$REPO_ROOT" "$@"
  fi
}

pull_repo() {
  [ "$AUTO_PULL" -eq 1 ] || {
    ok "Git pull skipped"
    return 0
  }

  command -v git >/dev/null 2>&1 || {
    warn "git missing; Git pull skipped"
    return 0
  }

  if ! git_repo_cmd rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "No Git checkout detected; Git pull skipped"
    return 0
  fi

  ok "Aktualisiere Checkout: git pull --ff-only"
  git_repo_cmd pull --ff-only || fail "Git pull failed; use --no-pull to install from the existing checkout"
  ok "Git pull completed"
}


install_bin_optional() {
  local name="$1"
  local mode="${2:-0750}"
  local src="$REPO_ROOT/files/usr/local/bin/$name"
  local dst="/usr/local/bin/$name"

  [ -f "$src" ] || {
    warn "Optional tool not found in repository: $src"
    return 0
  }

  install -d -o root -g root -m 0755 /usr/local/bin
  install -o root -g root -m "$mode" "$src" "$dst"
  ok "optional tool installed: $dst"
}

install_sbin() {
  local name="$1"
  local mode="${2:-0750}"
  local src="$REPO_ROOT/files/usr/local/sbin/$name"
  local dst="/usr/local/sbin/$name"

  [ -f "$src" ] || fail "Source missing: $src"
  install -o root -g root -m "$mode" "$src" "$dst"
  ok "installed: $dst"
}

install_i18n_files() {
  local src_dir="$REPO_ROOT/files/usr/local/share/vdisk-relay/i18n"
  local dst_dir="/usr/local/share/vdisk-relay/i18n"
  [ -d "$src_dir" ] || {
    warn "i18n directory not found in repository: $src_dir"
    return 0
  }

  install -d -o root -g root -m 0755 "$dst_dir"
  local src
  for src in "$src_dir"/*.json; do
    [ -f "$src" ] || continue
    install -o root -g root -m 0644 "$src" "$dst_dir/$(basename "$src")"
    ok "language file installed: $dst_dir/$(basename "$src")"
  done
}

install_unit() {
  local src="$1"
  local dst="/etc/systemd/system/$(basename "$src")"

  install -o root -g root -m 0644 "$src" "$dst"
  ok "systemd unit installed: $dst"
}

ensure_config_default() {
  local conf="$1"
  local key="$2"
  local value="$3"

  grep -Eq "^${key}=" "$conf" && return 1
  printf '%s="%s"\n' "$key" "$value" >> "$conf"
  return 0
}

ensure_config_defaults() {
  local conf="$1"
  local changed=0

  [ -f "$conf" ] || return 0

  ensure_config_default "$conf" DATA_ROOT "$INSTALL_DATA_ROOT" && changed=1
  ensure_config_default "$conf" MAX_DATA_AGE_SECONDS "$INSTALL_MAX_DATA_AGE_SECONDS" && changed=1
  ensure_config_default "$conf" IMAGE_STALE_SECONDS "$INSTALL_MAX_DATA_AGE_SECONDS" && changed=1
  ensure_config_default "$conf" SOURCE_DEFAULT_RETRIES "$INSTALL_SOURCE_DEFAULT_RETRIES" && changed=1
  ensure_config_default "$conf" SOURCE_DEFAULT_WAIT_SECONDS "$INSTALL_SOURCE_DEFAULT_WAIT_SECONDS" && changed=1
  ensure_config_default "$conf" SOURCE_LAST_STATE_DIR "$INSTALL_SOURCE_LAST_STATE_DIR" && changed=1
  ensure_config_default "$conf" SOURCE_TMP_LOG_DIR "$INSTALL_SOURCE_TMP_LOG_DIR" && changed=1
  ensure_config_default "$conf" SOURCE_DEFAULT_EXTENSION "$INSTALL_SOURCE_DEFAULT_EXTENSION" && changed=1
  ensure_config_default "$conf" PREVIEW_NEW_PER_RUN "$INSTALL_PREVIEW_NEW_PER_RUN" && changed=1
  ensure_config_default "$conf" PREVIEW_FFMPEG_TIMEOUT "$INSTALL_PREVIEW_FFMPEG_TIMEOUT" && changed=1
  ensure_config_default "$conf" PREVIEW_LONG_FFMPEG_TIMEOUT "$INSTALL_PREVIEW_LONG_FFMPEG_TIMEOUT" && changed=1
  ensure_config_default "$conf" PREVIEW_SCAN_MAX_FILES "$INSTALL_PREVIEW_SCAN_MAX_FILES" && changed=1
  ensure_config_default "$conf" PREVIEW_CACHE_MAX_FILES "$INSTALL_PREVIEW_CACHE_MAX_FILES" && changed=1
  ensure_config_default "$conf" PREVIEW_OFFSET_SECONDS "$INSTALL_PREVIEW_OFFSET_SECONDS" && changed=1
  ensure_config_default "$conf" PREVIEW_SMALL_VIDEO_BYTES "$INSTALL_PREVIEW_SMALL_VIDEO_BYTES" && changed=1
  ensure_config_default "$conf" PREVIEW_ATTEMPTS_PER_RUN "$INSTALL_PREVIEW_ATTEMPTS_PER_RUN" && changed=1
  ensure_config_default "$conf" WEB_SCREENSAVER_IDLE_MINUTES "$INSTALL_SCREEN_SAVER_IDLE_MINUTES" && changed=1
  ensure_config_default "$conf" WEB_SCREENSAVER_MODE "$INSTALL_SCREEN_SAVER_MODE" && changed=1
  ensure_config_default "$conf" LIVE_FAST_LANE_ENABLED "$INSTALL_LIVE_FAST_LANE_ENABLED" && changed=1
  ensure_config_default "$conf" LIVE_FAST_LANE_DELAY_SECONDS "$INSTALL_LIVE_FAST_LANE_DELAY_SECONDS" && changed=1
  ensure_config_default "$conf" LIVE_FAST_QUIET_SECONDS "$INSTALL_LIVE_FAST_QUIET_SECONDS" && changed=1
  ensure_config_default "$conf" TIMELINE_TRACE_ENABLED "$INSTALL_TIMELINE_TRACE_ENABLED" && changed=1
  ensure_config_default "$conf" TIMELINE_TRACE_FILE "$INSTALL_TIMELINE_TRACE_FILE" && changed=1
  ensure_config_default "$conf" TIMELINE_TRACE_SYSTEM_SNAPSHOT "$INSTALL_TIMELINE_TRACE_SYSTEM_SNAPSHOT" && changed=1
  ensure_config_default "$conf" TELEGRAM_TRACE_REPLY_BODY "$INSTALL_TELEGRAM_TRACE_REPLY_BODY" && changed=1
  ensure_config_default "$conf" TELEGRAM_TRACE_REPLY_MAX_BYTES "$INSTALL_TELEGRAM_TRACE_REPLY_MAX_BYTES" && changed=1
  ensure_config_default "$conf" DELETE_PREVIEW_WITH_VIDEO "$INSTALL_DELETE_PREVIEW_WITH_VIDEO" && changed=1
  ensure_config_default "$conf" ULTRA_FAST_LANE_ENABLED "$INSTALL_ULTRA_FAST_LANE_ENABLED" && changed=1
  ensure_config_default "$conf" ULTRA_FAST_LANE_DELAY_SECONDS "$INSTALL_ULTRA_FAST_LANE_DELAY_SECONDS" && changed=1
  ensure_config_default "$conf" ULTRA_FAST_LANE_QUIET_SECONDS "$INSTALL_ULTRA_FAST_LANE_QUIET_SECONDS" && changed=1
  ensure_config_default "$conf" ULTRA_FAST_LANE_SYNC_AFTER_SEND "$INSTALL_ULTRA_FAST_LANE_SYNC_AFTER_SEND" && changed=1
  ensure_config_default "$conf" ULTRA_FAST_DUPLICATE_MODE "$INSTALL_ULTRA_FAST_DUPLICATE_MODE" && changed=1
  ensure_config_default "$conf" ULTRA_FAST_REMAINDER_QUEUE_ENABLED "$INSTALL_ULTRA_FAST_REMAINDER_QUEUE_ENABLED" && changed=1
  ensure_config_default "$conf" ULTRA_FAST_REMAINDER_QUEUE_DELAY_SECONDS "$INSTALL_ULTRA_FAST_REMAINDER_QUEUE_DELAY_SECONDS" && changed=1
  ensure_config_default "$conf" TELEGRAM_QUEUE_ENABLED "$INSTALL_TELEGRAM_QUEUE_ENABLED" && changed=1
  ensure_config_default "$conf" TELEGRAM_QUEUE_RETRY_SECONDS "$INSTALL_TELEGRAM_QUEUE_RETRY_SECONDS" && changed=1
  ensure_config_default "$conf" TELEGRAM_QUEUE_MAX_ATTEMPTS "$INSTALL_TELEGRAM_QUEUE_MAX_ATTEMPTS" && changed=1
  ensure_config_default "$conf" TELEGRAM_QUEUE_PROCESS_LIMIT "$INSTALL_TELEGRAM_QUEUE_PROCESS_LIMIT" && changed=1
  ensure_config_default "$conf" TELEGRAM_QUEUE_DONE_MAX_FILES "$INSTALL_TELEGRAM_QUEUE_DONE_MAX_FILES" && changed=1

  ensure_config_default "$conf" NETWORK_GUARDIAN_ENABLED "$INSTALL_NETWORK_GUARDIAN_ENABLED" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_CHECK_INTERVAL_SECONDS "$INSTALL_NETWORK_GUARDIAN_CHECK_INTERVAL_SECONDS" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_FAILS_BEFORE_AP "$INSTALL_NETWORK_GUARDIAN_FAILS_BEFORE_AP" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_RECONNECT_WAIT_SECONDS "$INSTALL_NETWORK_GUARDIAN_RECONNECT_WAIT_SECONDS" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_AP_MIN_SECONDS "$INSTALL_NETWORK_GUARDIAN_AP_MIN_SECONDS" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_UI_HEARTBEAT_SECONDS "$INSTALL_NETWORK_GUARDIAN_UI_HEARTBEAT_SECONDS" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_UI_ACTIVE_GRACE_SECONDS "$INSTALL_NETWORK_GUARDIAN_UI_ACTIVE_GRACE_SECONDS" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_RECOVERY_WAIT_SECONDS "$INSTALL_NETWORK_GUARDIAN_RECOVERY_WAIT_SECONDS" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_AUTO_REBOOT_ENABLED "$INSTALL_NETWORK_GUARDIAN_AUTO_REBOOT_ENABLED" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_AUTO_REBOOT_AFTER_AP_CYCLES "$INSTALL_NETWORK_GUARDIAN_AUTO_REBOOT_AFTER_AP_CYCLES" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_AP_SSID_PREFIX "$INSTALL_NETWORK_GUARDIAN_AP_SSID_PREFIX" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_AP_PASSWORD "$INSTALL_NETWORK_GUARDIAN_AP_PASSWORD" && changed=1
  ensure_config_default "$conf" NETWORK_GUARDIAN_AP_IPV4 "$INSTALL_NETWORK_GUARDIAN_AP_IPV4" && changed=1

  if [ "$changed" -eq 1 ]; then
    chmod 0644 "$conf"
    ok "Configuration defaults added: WebUI/Network Guardian/Fast-Lane in $conf"
  fi
}

install_config() {
  local src="$REPO_ROOT/files/etc/vdisk-relay.conf"
  local dst="/etc/vdisk-relay.conf"

  [ -f "$src" ] || fail "Config-Source missing: $src"

  if [ -f "$dst" ] && [ "$FORCE_CONFIG" -ne 1 ]; then
    ensure_config_defaults "$dst"
    ok "Config remains unchanged: $dst"
    return 0
  fi

  if [ -f "$dst" ]; then
    cp -a "$dst" "${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    ok "config backup created: ${dst}.bak.*"
  fi

  install -o root -g root -m 0644 "$src" "$dst"
  ok "config installed: $dst"
}

install_secret_templates() {
  install -d -o root -g root -m 0755 /etc
  install -d -o root -g root -m 0700 /root

  if [ -f "$REPO_ROOT/deploy/bookworm/templates/vdisk-relay.env.template" ]; then
    install -o root -g root -m 0600 \
      "$REPO_ROOT/deploy/bookworm/templates/vdisk-relay.env.template" \
      /etc/vdisk-relay.env.example
    ok "secret template installed: /etc/vdisk-relay.env.example"
  fi

  if [ ! -f /etc/vdisk-relay.env ]; then
    install -o root -g root -m 0600 /etc/vdisk-relay.env.example /etc/vdisk-relay.env
    warn "/etc/vdisk-relay.env created from template; values still need to be set"
  else
    ok "Secret file remains unchanged: /etc/vdisk-relay.env"
  fi

  if [ -f "$REPO_ROOT/deploy/bookworm/templates/vdisk-relay-rsync.pass.template" ]; then
    install -o root -g root -m 0600 \
      "$REPO_ROOT/deploy/bookworm/templates/vdisk-relay-rsync.pass.template" \
      /root/vdisk-relay-rsync.pass.example
    ok "secret template installed: /root/vdisk-relay-rsync.pass.example"
  fi

  if [ ! -f /root/vdisk-relay-rsync.pass ]; then
    warn "/root/vdisk-relay-rsync.pass missing; run deploy/bookworm/wizard.sh"
  else
    chmod 0600 /root/vdisk-relay-rsync.pass
    ok "rsync password file available: /root/vdisk-relay-rsync.pass"
  fi
}

install_motd() {
  local src="$REPO_ROOT/files/etc/update-motd.d/99-vdisk-relay"
  local dst="/etc/update-motd.d/99-vdisk-relay"
  local backup_dir="/var/lib/vdisk-relay/disabled-motd-hooks"
  local hook target backup tmp

  [ "$INSTALL_MOTD" -eq 1 ] || {
    ok "MOTD installation skipped"
    return 0
  }

  install -d -o root -g root -m 0755 "$backup_dir"

  for hook in /etc/update-motd.d/*; do
    [ -f "$hook" ] || continue
    [ "$hook" = "$dst" ] && continue

    if grep -Eq 'vdisk-relay|video-vdisk|status-login\.txt|status-lights' "$hook" 2>/dev/null; then
      backup="$backup_dir/$(basename "$hook").disabled.$(date +%Y%m%d-%H%M%S)"
      mv "$hook" "$backup"
      chmod 0644 "$backup"
      ok "Old vdisk-relay MOTD hook disabled: $hook"
    fi
  done

  if [ -L /etc/motd ]; then
    target="$(readlink -f /etc/motd 2>/dev/null || true)"
    if [ "$target" = "/run/motd.dynamic" ]; then
      rm -f /etc/motd
      : > /etc/motd
      chown root:root /etc/motd
      chmod 0644 /etc/motd
      ok "duplicate MOTD source removed: /etc/motd pointed to /run/motd.dynamic"
    fi
  elif [ -f /etc/motd ] && grep -q '^=== vdisk-relay status ===' /etc/motd 2>/dev/null; then
    backup="/var/lib/vdisk-relay/motd.vdisk-relay-duplicate.$(date +%Y%m%d-%H%M%S)"
    cp -a /etc/motd "$backup"
    tmp="$(mktemp)"
    awk '
      /^=== vdisk-relay status ===$/ { skip=1; next }
      skip && /^updated=/ { skip=0; next }
      !skip { print }
    ' /etc/motd > "$tmp"
    install -o root -g root -m 0644 "$tmp" /etc/motd
    rm -f "$tmp"
    ok "Statischen vdisk-relay State off /etc/motd entfernt"
  fi

  if [ -f "$src" ]; then
    install -o root -g root -m 0755 "$src" "$dst"
    ok "MOTD installed: $dst"
  else
    warn "MOTD file not found in repository: $src"
  fi
}

unit_exists() {
  local unit="$1"
  systemctl_fast cat "$unit" >/dev/null 2>&1
}

unit_active() {
  local unit="$1"
  systemctl_fast is-active --quiet "$unit"
}

systemctl_fast() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$SYSTEMCTL_JOB_TIMEOUT" systemctl "$@"
  else
    systemctl "$@"
  fi
}

systemctl_enable_now_fast() {
  local unit="$1"

  systemctl_fast enable "$unit" || {
    warn "Unit could not be enabled: $unit"
    return 0
  }
  systemctl_fast --no-block start "$unit" || warn "Unit could not be started: $unit"
}

systemctl_enable_fast() {
  local unit="$1"
  local mode="${2:-}"

  if [ -n "$mode" ]; then
    systemctl_fast enable "$mode" "$unit" || warn "Unit could not be enabled: $unit"
  else
    systemctl_fast enable "$unit" || warn "Unit could not be enabled: $unit"
  fi
}

cleanup_legacy_video_vdisk_units() {
  local unit path
  local units=()

  while read -r unit _rest; do
    [ -n "$unit" ] || continue
    units+=("$unit")
  done < <(
    {
      systemctl_fast list-unit-files 'video-vdisk-*' --no-legend --no-pager 2>/dev/null || true
      systemctl_fast list-units --all 'video-vdisk-*' --no-legend --no-pager 2>/dev/null || true
    } | awk '{print $1}' | sort -u
  )

  for unit in "${units[@]}"; do
    [ -n "$unit" ] || continue
    systemctl_fast disable "$unit" >/dev/null 2>&1 || true
  done

  if [ "${#units[@]}" -gt 0 ]; then
    systemctl_fast --no-block stop "${units[@]}" >/dev/null 2>&1 || true
    ok "old video-vdisk units disabled/stopped: ${#units[@]}"
  fi

  for path in /etc/systemd/system/video-vdisk-*; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    rm -rf "$path"
    ok "old video-vdisk systemd file removed: $path"
  done
}

cleanup_obsolete_systemd_units() {
  local unit path dir
  local existing=()

  cleanup_legacy_video_vdisk_units

  for unit in "${OBSOLETE_SYSTEMD_UNITS[@]}"; do
    unit_exists "$unit" || continue
    existing+=("$unit")
    systemctl_fast disable "$unit" >/dev/null 2>&1 || true
  done

  if [ "${#existing[@]}" -gt 0 ]; then
    systemctl_fast --no-block stop "${existing[@]}" >/dev/null 2>&1 || true
  fi

  for path in "${OBSOLETE_SYSTEMD_PATHS[@]}"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      rm -f "$path"
      ok "obsolete systemd file removed: $path"
    fi
  done

  for dir in \
    /etc/systemd/system/vdisk-relay-status.service.d \
    /etc/systemd/system/vdisk-relay-web-status-cache.service.d
  do
    rmdir "$dir" 2>/dev/null || true
  done
}

refresh_web_after_update() {
  [ "$RESTART_ACTIVE" -eq 1 ] || return 0
  [ "$INSTALL_WEB" -eq 1 ] || return 0
  unit_exists vdisk-relay-web.service || return 0

  systemctl_fast enable vdisk-relay-web.service || warn "WebUI could not be enabled"
  if unit_active vdisk-relay-web.service; then
    systemctl_fast --no-block restart vdisk-relay-web.service || warn "WebUI restart could not be triggered"
    ok "WebUI restart triggered"
  else
    systemctl_fast --no-block start vdisk-relay-web.service || warn "WebUI could not be started"
    ok "WebUI start triggered"
  fi
}

start_cache_if_available() {
  local unit="$1"

  unit_exists "$unit" || return 0

  systemctl_fast --no-block start "$unit" || warn "Cache service could not be triggered: $unit"
  ok "cache service triggered: $unit"
}

config_ready() {
  [ -x /usr/local/sbin/vdisk-relay ] || return 1
  /usr/local/sbin/vdisk-relay config-ready >/dev/null 2>&1
}

disable_runtime_for_setup() {
  local units=(
    vdisk-relay-gadget-live.service
    vdisk-relay-watch-live.path
    vdisk-relay-trigger-live.service
    vdisk-relay-fast-sync.service
    vdisk-relay-ultra-fast-sync.service
    vdisk-relay-sync-live.service
    vdisk-relay-telegram-queue.service
    vdisk-relay-telegram-queue.timer
    vdisk-relay-retry-live.service
    vdisk-relay-retry-live.timer
    vdisk-relay-image-mtime-watch.service
    vdisk-relay-image-mtime-watch.timer
    vdisk-relay-watchdog-live.service
    vdisk-relay-watchdog-live.timer
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
    vdisk-relay-network-guardian.service
    vdisk-relay-network-guardian.timer
    vdisk-relay-preview-cache.service
    vdisk-relay-preview-cache.timer
    vdisk-relay-update.service
    vdisk-relay-update-check.service
    vdisk-relay-update-check.timer
    vdisk-relay-format-on-boot.service
  )
  local unit
  local existing=()

  for unit in "${units[@]}"; do
    unit_exists "$unit" || continue
    existing+=("$unit")
    systemctl_fast disable "$unit" >/dev/null 2>&1 || true
  done

  if [ "${#existing[@]}" -gt 0 ]; then
    systemctl_fast --no-block stop "${existing[@]}" >/dev/null 2>&1 || true
  fi

  if [ "$INSTALL_WEB" -eq 1 ] && unit_exists vdisk-relay-web.service; then
    systemctl_fast enable vdisk-relay-web.service || warn "WebUI could not be enabled"
    systemctl_fast --no-block start vdisk-relay-web.service || warn "WebUI could not be started"
  fi

  warn "Required configuration missing; runtime services paused, WebUI/wizard remains active"
}

refresh_runtime_after_update() {
  [ "$RESTART_ACTIVE" -eq 1 ] || {
    ok "restart/cache refresh skipped"
    return 0
  }

  if ! config_ready; then
    disable_runtime_for_setup
    return 0
  fi

  start_cache_if_available vdisk-relay-status-cache.service

  if [ "$INSTALL_WEB" -eq 1 ]; then
    start_cache_if_available vdisk-relay-web-status-cache.service
    start_cache_if_available vdisk-relay-debug-cache.service
    start_cache_if_available vdisk-relay-preview-cache.service
    start_cache_if_available vdisk-relay-update-check.service
  fi
}

install_files() {
  install -d -o root -g root -m 0755 /usr/local/sbin
  install -d -o root -g root -m 0755 /usr/local/share/vdisk-relay/i18n
  install -d -o root -g root -m 0755 /etc/systemd/system
  install -d -o root -g root -m 0755 /files
  install -d -o root -g root -m 0700 \
    /var/lib/vdisk-relay \
    /var/lib/vdisk-relay/last \
    /var/lib/vdisk-relay/shadow \
    /var/lib/vdisk-relay/telegram-queue \
    /var/lib/vdisk-relay/telegram-queue/pending \
    /var/lib/vdisk-relay/telegram-queue/processing \
    /var/lib/vdisk-relay/telegram-queue/done \
    /var/lib/vdisk-relay/telegram-queue/failed
  install -d -o root -g root -m 0755 /var/lib/vdisk-relay/update
  install -d -o root -g root -m 0755 /run/vdisk-relay /run/vdisk-relay-www
  install -d -o root -g root -m 0755 /var/cache/vdisk-relay-previews

  printf '%s\n' "$REPO_ROOT" > /var/lib/vdisk-relay/repo-root
  chmod 0644 /var/lib/vdisk-relay/repo-root
  ok "Repository path for web updates stored: /var/lib/vdisk-relay/repo-root"

  install_sbin vdisk-relay 0750
  install_sbin video-vdisk 0755
  install_bin_optional format-vdisk 0750
  install_bin_optional watch-preview-debug-log 0750
  install_bin_optional watch-preview-log 0750

  if [ -f "$REPO_ROOT/files/usr/local/sbin/vdisk-relay-status-cache" ]; then
    install_sbin vdisk-relay-status-cache 0755
  fi

  if [ -f "$REPO_ROOT/files/usr/local/sbin/vdisk-relay-network-guardian" ]; then
    install_sbin vdisk-relay-network-guardian 0755
  fi

  if [ -f "$REPO_ROOT/files/usr/local/sbin/vdisk-relay-update-check" ]; then
    install_sbin vdisk-relay-update-check 0755
    install_sbin vdisk-relay-update-run 0750
    install_sbin vdisk-relay-git-askpass 0750
  fi

  if [ "$INSTALL_WEB" -eq 1 ] && [ -f "$REPO_ROOT/files/usr/local/sbin/vdisk-relay-web-status-cache" ]; then
    install_sbin vdisk-relay-web-status-cache 0755
    install_sbin vdisk-relay-debug-cache 0755
    install_sbin vdisk-relay-preview-cache 0755
    install_sbin vdisk-relay-web-admin 0755
    install_i18n_files
  fi

  install_config
  install_secret_templates
  install_motd
  cleanup_obsolete_systemd_units

  for src in "$REPO_ROOT"/files/etc/systemd/system/vdisk-relay-*; do
    [ -f "$src" ] || continue

    if [ "$INSTALL_WEB" -ne 1 ] && echo "$src" | grep -q 'web'; then
      ok "web unit skipped: $(basename "$src")"
      continue
    fi

    install_unit "$src"
  done

  systemctl_fast daemon-reload
  ok "systemd daemon-reload completed"

  refresh_runtime_after_update
}

set_gates() {
  touch /etc/vdisk-relay.live-enabled
  touch /etc/vdisk-relay.allow-gadget
  touch /etc/vdisk-relay.allow-watch
  touch /etc/vdisk-relay.allow-trigger
  touch /etc/vdisk-relay.allow-sync
  touch /etc/vdisk-relay.allow-archive
  touch /etc/vdisk-relay.allow-health-reboot
  touch /etc/vdisk-relay.allow-boot-notify
  touch /etc/vdisk-relay.allow-network-guardian
  ok "Live gates set"
}

live_gate_state_exists() {
  [ -e /etc/vdisk-relay.live-enabled ] && return 0

  local gate
  for gate in /etc/vdisk-relay.allow-*; do
    [ -e "$gate" ] && return 0
  done

  return 1
}

gate_enabled() {
  local gate="$1"

  [ -e /etc/vdisk-relay.live-enabled ] && [ -e "$gate" ]
}

live_runtime_enabled() {
  local unit
  for unit in \
    vdisk-relay-gadget-live.service \
    vdisk-relay-watch-live.path \
    vdisk-relay-retry-live.timer \
    vdisk-relay-telegram-queue.timer \
    vdisk-relay-image-mtime-watch.timer \
    vdisk-relay-watchdog-live.timer \
    vdisk-relay-archive-live.timer \
    vdisk-relay-health-live.timer \
    vdisk-relay-network-guardian.timer
  do
    unit_exists "$unit" || continue
    systemctl_fast is-enabled --quiet "$unit" && return 0
  done

  return 1
}

enable_unit_if_gate() {
  local unit="$1"
  local gate="$2"
  local mode="${3:-}"

  if gate_enabled "$gate"; then
    if [ "$mode" = "--now" ]; then
      systemctl_enable_now_fast "$unit"
    elif [ -n "$mode" ]; then
      systemctl_enable_fast "$unit" "$mode"
    else
      systemctl_enable_fast "$unit"
    fi
  else
    ok "gate missing, unit remains unchanged: $unit"
  fi
}

enable_live_services() {
  local reason="${1:-force}"
  local gate_mode="${2:-defaults}"

  if ! config_ready; then
    disable_runtime_for_setup
    return 0
  fi

  if [ "$gate_mode" = "defaults" ]; then
    set_gates
  else
    ok "Existing live gates are used"
  fi

  enable_unit_if_gate vdisk-relay-gadget-live.service /etc/vdisk-relay.allow-gadget --now
  enable_unit_if_gate vdisk-relay-watch-live.path /etc/vdisk-relay.allow-watch --now
  enable_unit_if_gate vdisk-relay-retry-live.timer /etc/vdisk-relay.allow-sync --now
  enable_unit_if_gate vdisk-relay-telegram-queue.timer /etc/vdisk-relay.allow-sync --now
  enable_unit_if_gate vdisk-relay-image-mtime-watch.timer /etc/vdisk-relay.allow-sync --now
  enable_unit_if_gate vdisk-relay-watchdog-live.timer /etc/vdisk-relay.allow-sync --now
  enable_unit_if_gate vdisk-relay-archive-live.timer /etc/vdisk-relay.allow-archive --now
  enable_unit_if_gate vdisk-relay-health-live.timer /etc/vdisk-relay.allow-health-reboot --now
  enable_unit_if_gate vdisk-relay-boot-notify-live.service /etc/vdisk-relay.allow-boot-notify

  if [ -f /etc/systemd/system/vdisk-relay-status-cache.timer ]; then
    systemctl_enable_now_fast vdisk-relay-status-cache.timer
    start_cache_if_available vdisk-relay-status-cache.service
  fi

  if [ "$INSTALL_WEB" -eq 1 ] && [ -f /etc/systemd/system/vdisk-relay-web.service ]; then
    systemctl_enable_now_fast vdisk-relay-web-status-cache.timer
    systemctl_enable_now_fast vdisk-relay-debug-cache.timer
    systemctl_enable_now_fast vdisk-relay-preview-cache.timer
    enable_unit_if_gate vdisk-relay-network-guardian.timer /etc/vdisk-relay.allow-network-guardian --now
    systemctl_enable_now_fast vdisk-relay-update-check.timer
    start_cache_if_available vdisk-relay-debug-cache.service
    start_cache_if_available vdisk-relay-web-status-cache.service
    start_cache_if_available vdisk-relay-preview-cache.service
    start_cache_if_available vdisk-relay-update-check.service
    systemctl_enable_now_fast vdisk-relay-web.service
  fi

  ok "Live services enabled ($reason)"
}

enable_new_units_for_existing_gates() {
  enable_unit_if_gate vdisk-relay-watchdog-live.timer /etc/vdisk-relay.allow-sync --now
  enable_unit_if_gate vdisk-relay-image-mtime-watch.timer /etc/vdisk-relay.allow-sync --now
  enable_unit_if_gate vdisk-relay-telegram-queue.timer /etc/vdisk-relay.allow-sync --now
}

auto_live_services() {
  case "$LIVE_MODE" in
    skip)
      warn "initial live activation skipped by --no-live"
      return 0
      ;;
    force)
      enable_live_services "force" "defaults"
      return 0
      ;;
  esac

  if ! config_ready; then
    warn "Required configuration missing; initial live activation waits for setup/wizard"
    return 0
  fi

  if live_gate_state_exists; then
    if live_runtime_enabled; then
      ok "live gates and enabled live units present; missing gate-bound units will be enabled"
      enable_new_units_for_existing_gates
    else
      enable_live_services "auto-existing-gates" "preserve"
    fi
    return 0
  fi

  enable_live_services "auto" "defaults"
}

verify_install() {
  echo
  echo "=== Verification ==="

  /usr/local/sbin/vdisk-relay status-lights || warn "status-lights reports a red state"

  echo
  systemctl_fast list-timers --all | grep vdisk-relay || warn "No vdisk-relay timers visible"

  echo
  systemctl_fast --failed || true
}

pull_repo
install_files
auto_live_services
refresh_web_after_update

verify_install
ok "Installation completed"
