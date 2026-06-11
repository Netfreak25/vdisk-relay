#!/usr/bin/env bash
set -Eeuo pipefail

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "Wizard must run as root"

DEFAULT_IMAGE_FILE="/usbdisk.img"
DEFAULT_DATA_ROOT="/files"
DEFAULT_RSYNC_PASS_FILE="/root/vdisk-relay-rsync.pass"
DEFAULT_SOURCE_ID="source1"
DEFAULT_SOURCE_PROFILE="generic-media-drop"
DEFAULT_SOURCE_EXTENSIONS="mp4"
DEFAULT_SOURCE_TELEGRAM_MODE="auto"
DEFAULT_SOURCE_TIME_MODE="mtime"
DEFAULT_SOURCE_TIMEZONE="UTC"
DEFAULT_DISPLAY_TIMEZONE="Europe/Berlin"

ask_default() {
  local var_name="$1"
  local prompt="$2"
  local default="$3"
  local example="${4:-}"
  local value

  if [ -n "$example" ]; then
    warn "Example: $example"
  fi

  read -r -p "$prompt [$default]: " value
  value="${value:-$default}"
  printf -v "$var_name" '%s' "$value"
}

ask_required() {
  local var_name="$1"
  local prompt="$2"
  local example="${3:-}"
  local value

  if [ -n "$example" ]; then
    warn "Example: $example"
  fi

  while true; do
    read -r -p "$prompt: " value
    if [ -n "$value" ]; then
      printf -v "$var_name" '%s' "$value"
      return 0
    fi
    warn "Value must not be empty"
  done
}

ask_secret_required() {
  local var_name="$1"
  local prompt="$2"
  local value

  while true; do
    read -r -s -p "$prompt: " value
    echo
    if [ -n "$value" ]; then
      printf -v "$var_name" '%s' "$value"
      return 0
    fi
    warn "Value must not be empty"
  done
}

ask_yes_no() {
  local var_name="$1"
  local prompt="$2"
  local default="$3"
  local answer

  read -r -p "$prompt [$default]: " answer
  answer="${answer:-$default}"

  case "$answer" in
    y|Y|yes|YES) printf -v "$var_name" '1' ;;
    n|N|no|NO) printf -v "$var_name" '0' ;;
    *) fail "Invalid answer: $answer" ;;
  esac
}

backup_if_exists() {
  local f="$1"
  if [ -e "$f" ]; then
    cp -a "$f" "${f}.bak.$(date +%Y%m%d-%H%M%S)"
    ok "Backup created: ${f}.bak.*"
  fi
}

env_id() {
  local value="$1"
  value="${value^^}"
  value="${value//-/_}"
  value="${value// /_}"
  value="$(printf '%s' "$value" | tr -cd 'A-Z0-9_')"
  [ -n "$value" ] || value="PRIMARY"
  printf '%s' "$value"
}

shell_quote() {
  local value="$1"
  printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}

validate_plain() {
  local value="$1"
  local name="$2"
  case "$value" in
    *$'\n'*|*$'\r'*|*"|"*) fail "$name must not contain newlines or pipe characters" ;;
  esac
}

chat_type_from_id() {
  local chat_id="$1"
  case "$chat_id" in
    -100*) printf 'supergroup\n' ;;
    -*) printf 'group\n' ;;
    *) printf 'private\n' ;;
  esac
}

write_gate() {
  local path="$1"
  touch "$path"
}

echo "=== VDisk Relay Configuration Wizard ==="
echo
echo "All optional sections can be skipped. Skipped features stay disabled and can be configured later in the WebUI."
echo

ask_default IMAGE_FILE "Image file" "$DEFAULT_IMAGE_FILE" "$DEFAULT_IMAGE_FILE"
ask_default DATA_ROOT "Local data root" "$DEFAULT_DATA_ROOT" "$DEFAULT_DATA_ROOT"
validate_plain "$IMAGE_FILE" "Image file"
validate_plain "$DATA_ROOT" "Local data root"

CONFIGURE_ARCHIVE=0
RSYNC_TARGET=""
RSYNC_PASS_FILE="$DEFAULT_RSYNC_PASS_FILE"
RSYNC_PASS=""
echo
echo "=== Archive (optional) ==="
ask_yes_no CONFIGURE_ARCHIVE "Configure rsync-daemon archive now?" "n"
if [ "$CONFIGURE_ARCHIVE" = "1" ]; then
  ask_required RSYNC_TARGET "Archive destination via rsync daemon" "user@host::module/path/"
  ask_default RSYNC_PASS_FILE "Rsync password file" "$DEFAULT_RSYNC_PASS_FILE" "$DEFAULT_RSYNC_PASS_FILE"
  ask_secret_required RSYNC_PASS "Rsync daemon password"
  validate_plain "$RSYNC_TARGET" "Archive destination"
  validate_plain "$RSYNC_PASS_FILE" "Rsync password file"
else
  warn "Archive skipped; archive gate will not be enabled."
fi

CONFIGURE_TELEGRAM=0
TELEGRAM_ID="PRIMARY"
BOT_VAR=""
CHAT_VAR=""
CHAT_TYPE_VAR=""
BOT_TOKEN=""
CHAT_ID=""
CHAT_TYPE=""
echo
echo "=== Telegram (optional) ==="
ask_yes_no CONFIGURE_TELEGRAM "Configure Telegram now?" "n"
if [ "$CONFIGURE_TELEGRAM" = "1" ]; then
  ask_default TELEGRAM_ID "Telegram variable base name" "PRIMARY" "PRIMARY"
  TELEGRAM_ID="$(env_id "$TELEGRAM_ID")"
  BOT_VAR="${TELEGRAM_ID}_BOT_TOKEN"
  CHAT_VAR="${TELEGRAM_ID}_CHAT_ID"
  CHAT_TYPE_VAR="${TELEGRAM_ID}_CHAT_TYPE"
  ask_secret_required BOT_TOKEN "$BOT_VAR"
  ask_required CHAT_ID "$CHAT_VAR" "-1001234567890"
  CHAT_TYPE="$(chat_type_from_id "$CHAT_ID")"
  validate_plain "$BOT_TOKEN" "$BOT_VAR"
  validate_plain "$CHAT_ID" "$CHAT_VAR"
else
  warn "Telegram skipped; Telegram-dependent gates will not be enabled."
fi

CONFIGURE_SOURCE=0
SOURCE_ID="$DEFAULT_SOURCE_ID"
SOURCE_LABEL="$DEFAULT_SOURCE_ID"
SOURCE_PROFILE="$DEFAULT_SOURCE_PROFILE"
SOURCE_MATCH="*"
SOURCE_EXTENSIONS="$DEFAULT_SOURCE_EXTENSIONS"
SOURCE_TELEGRAM_MODE="$DEFAULT_SOURCE_TELEGRAM_MODE"
SOURCE_TIME_MODE="$DEFAULT_SOURCE_TIME_MODE"
SOURCE_TIMEZONE="$DEFAULT_SOURCE_TIMEZONE"
SOURCE_DISPLAY_TIMEZONE="$DEFAULT_DISPLAY_TIMEZONE"
SOURCE_RETRIES="4"
SOURCE_WAIT="3"
TMP_LOG=""
LAST_STATE_FILE=""
SOURCE_ENTRY=""
echo
echo "=== First source (optional) ==="
ask_yes_no CONFIGURE_SOURCE "Create a first source now?" "y"
if [ "$CONFIGURE_SOURCE" = "1" ]; then
  ask_default SOURCE_ID "Source ID" "$DEFAULT_SOURCE_ID" "$DEFAULT_SOURCE_ID"
  SOURCE_ID="$(env_id "$SOURCE_ID")"
  SOURCE_ID="${SOURCE_ID,,}"
  SOURCE_ID="${SOURCE_ID//_/-}"
  ask_default SOURCE_LABEL "Source label" "$SOURCE_ID" "$SOURCE_ID"
  ask_default SOURCE_PROFILE "Source profile" "$DEFAULT_SOURCE_PROFILE" "$DEFAULT_SOURCE_PROFILE"
  ask_default SOURCE_MATCH "Filename match inside data root" "*" "*"
  ask_default SOURCE_EXTENSIONS "File extensions" "$DEFAULT_SOURCE_EXTENSIONS" "$DEFAULT_SOURCE_EXTENSIONS"
  ask_default SOURCE_TELEGRAM_MODE "Telegram mode" "$SOURCE_TELEGRAM_MODE" "$SOURCE_TELEGRAM_MODE"
  ask_default SOURCE_TIME_MODE "Time mode" "$SOURCE_TIME_MODE" "$SOURCE_TIME_MODE"
  ask_default SOURCE_TIMEZONE "Source timezone" "$SOURCE_TIMEZONE" "$SOURCE_TIMEZONE"
  ask_default SOURCE_DISPLAY_TIMEZONE "Display timezone" "$SOURCE_DISPLAY_TIMEZONE" "$SOURCE_DISPLAY_TIMEZONE"
  ask_default SOURCE_RETRIES "Telegram retries" "$SOURCE_RETRIES" "$SOURCE_RETRIES"
  ask_default SOURCE_WAIT "Seconds between retries" "$SOURCE_WAIT" "$SOURCE_WAIT"
  TMP_LOG="/run/vdisk-relay/${SOURCE_ID}.telegram.log"
  LAST_STATE_FILE="/var/lib/vdisk-relay/last/${SOURCE_ID}.last"

  validate_plain "$SOURCE_ID" "Source ID"
  validate_plain "$SOURCE_LABEL" "Source label"
  validate_plain "$SOURCE_PROFILE" "Source profile"
  validate_plain "$SOURCE_MATCH" "Filename match"
  validate_plain "$SOURCE_EXTENSIONS" "File extensions"
  validate_plain "$SOURCE_TELEGRAM_MODE" "Telegram mode"
  validate_plain "$SOURCE_TIME_MODE" "Time mode"
  validate_plain "$SOURCE_TIMEZONE" "Source timezone"
  validate_plain "$SOURCE_DISPLAY_TIMEZONE" "Display timezone"
  validate_plain "$SOURCE_RETRIES" "Telegram retries"
  validate_plain "$SOURCE_WAIT" "Retry wait"

  SOURCE_ENTRY="${SOURCE_ID}|1|${SOURCE_PROFILE}|${SOURCE_LABEL}|${SOURCE_MATCH}|${SOURCE_EXTENSIONS}|${SOURCE_TELEGRAM_MODE}|${SOURCE_TIME_MODE}|${SOURCE_TIMEZONE}|${SOURCE_DISPLAY_TIMEZONE}|${LAST_STATE_FILE}|${BOT_VAR}|${CHAT_VAR}|${SOURCE_RETRIES}|${SOURCE_WAIT}|${TMP_LOG}"
else
  warn "Source skipped; sync and health gates will not be enabled."
fi

SET_GATES=0
ENABLE_NETWORK_GUARDIAN=0
echo
echo "=== Live gates ==="
ask_yes_no SET_GATES "Create live gate files now?" "n"
if [ "$SET_GATES" = "1" ]; then
  ask_yes_no ENABLE_NETWORK_GUARDIAN "Enable Network Guardian gate now?" "n"
fi

backup_if_exists /etc/vdisk-relay.conf
backup_if_exists /etc/vdisk-relay.env
if [ "$CONFIGURE_ARCHIVE" = "1" ]; then
  backup_if_exists "$RSYNC_PASS_FILE"
fi

install -d -o root -g root -m 0755 /etc
if [ "$CONFIGURE_ARCHIVE" = "1" ]; then
  install -d -o root -g root -m 0700 "$(dirname "$RSYNC_PASS_FILE")"
fi

Q_IMAGE_FILE="$(shell_quote "$IMAGE_FILE")"
Q_DATA_ROOT="$(shell_quote "$DATA_ROOT")"
Q_GADGET_ARGS="$(shell_quote "file=$IMAGE_FILE stall=0 ro=0 removable=1 iSerialNumber=1234567890")"
Q_RSYNC_TARGET="$(shell_quote "$RSYNC_TARGET")"
Q_RSYNC_PASS_FILE="$(shell_quote "$RSYNC_PASS_FILE")"

cat > /etc/vdisk-relay.conf <<EOF_CONF
# VDisk Relay configuration
# Secrets live in /etc/vdisk-relay.env and optional password files.

IMAGE_FILE=$Q_IMAGE_FILE
MOUNTPOINT="/run/vdisk-relay/mnt"
DATA_ROOT=$Q_DATA_ROOT

STATE_DIR="/var/lib/vdisk-relay"
RUN_DIR="/run/vdisk-relay"
LOG_FILE="/var/log/vdisk-relay.log"

PARTITION_OFFSET_SECTORS="2048"
MOUNT_FSTYPE="vfat"

WATCH_EVENT="modify"
WATCH_DEBOUNCE_SECONDS="2"
MAX_DATA_AGE_SECONDS="100800"
LIVE_QUIET_SECONDS="8"
LIVE_FAST_LANE_ENABLED="1"
LIVE_FAST_LANE_DELAY_SECONDS="3"
LIVE_FAST_QUIET_SECONDS="3"
WEB_SCREENSAVER_IDLE_MINUTES="0"
WEB_SCREENSAVER_MODE="floating"
TIMELINE_TRACE_ENABLED="0"
TIMELINE_TRACE_FILE="/var/log/vdisk-relay-timeline.jsonl"
TIMELINE_TRACE_SYSTEM_SNAPSHOT="0"
TELEGRAM_TRACE_REPLY_BODY="0"
TELEGRAM_TRACE_REPLY_MAX_BYTES="20000"
ULTRA_FAST_LANE_ENABLED="0"
ULTRA_FAST_LANE_DELAY_SECONDS="0"
ULTRA_FAST_LANE_QUIET_SECONDS="0"
ULTRA_FAST_LANE_SYNC_AFTER_SEND="1"
ULTRA_FAST_DUPLICATE_MODE="filename"
ULTRA_FAST_REMAINDER_QUEUE_ENABLED="1"
ULTRA_FAST_REMAINDER_QUEUE_DELAY_SECONDS="2"

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

CURL_MAX_TIME="120"
TELEGRAM_TEXT_RETRIES="18"
TELEGRAM_TEXT_RETRY_DELAY="10"
TELEGRAM_TEXT_CURL_MAX_TIME="20"
BOOT_NOTIFY_WAIT_SECONDS="180"
BOOT_NOTIFY_WAIT_INTERVAL="5"
GADGET_MODPROBE_ARGS=$Q_GADGET_ARGS

SYNC_PASSES="0.5 4 10"
SYNC_RSYNC_OPTIONS="-r --ignore-existing"
SYNC_RSYNC_DRYRUN_OPTIONS="-n --ignore-existing --stats"

TELEGRAM_QUEUE_ENABLED="1"
TELEGRAM_QUEUE_RETRY_SECONDS="60"
TELEGRAM_QUEUE_MAX_ATTEMPTS="30"
TELEGRAM_QUEUE_PROCESS_LIMIT="2"
TELEGRAM_QUEUE_DONE_MAX_FILES="200"

ARCHIVE_RSYNC_TARGET=$Q_RSYNC_TARGET
ARCHIVE_RSYNC_PASSWORD_FILE=$Q_RSYNC_PASS_FILE
ARCHIVE_RSYNC_MAX_SECONDS="900"
ARCHIVE_RSYNC_CONTIMEOUT="10"
ARCHIVE_RSYNC_TIMEOUT="60"

SOURCE_DEFAULT_RETRIES="4"
SOURCE_DEFAULT_WAIT_SECONDS="3"
SOURCE_LAST_STATE_DIR="/var/lib/vdisk-relay/last"
SOURCE_TMP_LOG_DIR="/run/vdisk-relay"
SOURCE_DEFAULT_EXTENSION="mp4"

IMAGE_STALE_SECONDS="100800"
IMAGE_STALE_REBOOT_COOLDOWN_SECONDS="14400"

PREVIEW_NEW_PER_RUN="3"
PREVIEW_FFMPEG_TIMEOUT="180"
PREVIEW_LONG_FFMPEG_TIMEOUT="600"
PREVIEW_SCAN_MAX_FILES="5000"
PREVIEW_CACHE_MAX_FILES="5000"
PREVIEW_OFFSET_SECONDS="1"
PREVIEW_SMALL_VIDEO_BYTES="153600"
PREVIEW_ATTEMPTS_PER_RUN="4"

# id|enabled|profile|label|match|extensions|telegram_mode|time_mode|source_timezone|display_timezone|last_file|bot_var|chat_var|retries|wait_seconds|tmp_log
SOURCES=(
EOF_CONF

if [ "$CONFIGURE_SOURCE" = "1" ]; then
  printf '  %s\n' "$(shell_quote "$SOURCE_ENTRY")" >> /etc/vdisk-relay.conf
fi

cat >> /etc/vdisk-relay.conf <<EOF_CONF
)
EOF_CONF

chmod 0644 /etc/vdisk-relay.conf
ok "Wrote /etc/vdisk-relay.conf"

if [ "$CONFIGURE_TELEGRAM" = "1" ]; then
  cat > /etc/vdisk-relay.env <<EOF_ENV
$BOT_VAR=$(shell_quote "$BOT_TOKEN")
$CHAT_VAR=$(shell_quote "$CHAT_ID")
$CHAT_TYPE_VAR=$(shell_quote "$CHAT_TYPE")
EOF_ENV
else
  cat > /etc/vdisk-relay.env <<'EOF_ENV'
# No Telegram credentials configured by the wizard.
EOF_ENV
fi

chmod 0600 /etc/vdisk-relay.env
chown root:root /etc/vdisk-relay.env
ok "Wrote /etc/vdisk-relay.env"

if [ "$CONFIGURE_ARCHIVE" = "1" ]; then
  printf '%s\n' "$RSYNC_PASS" > "$RSYNC_PASS_FILE"
  chmod 0600 "$RSYNC_PASS_FILE"
  chown root:root "$RSYNC_PASS_FILE"
  ok "Wrote $RSYNC_PASS_FILE"
fi

install -d -o root -g root -m 0700 \
  /var/lib/vdisk-relay \
  /var/lib/vdisk-relay/last \
  /var/lib/vdisk-relay/shadow \
  /var/lib/vdisk-relay/telegram-queue \
  /var/lib/vdisk-relay/telegram-queue/pending \
  /var/lib/vdisk-relay/telegram-queue/processing \
  /var/lib/vdisk-relay/telegram-queue/done \
  /var/lib/vdisk-relay/telegram-queue/failed
install -d -o root -g root -m 0755 "$DATA_ROOT" /run/vdisk-relay /run/vdisk-relay-www /var/cache/vdisk-relay-previews
ok "Created state and runtime directories"

if [ "$SET_GATES" = "1" ]; then
  write_gate /etc/vdisk-relay.live-enabled
  write_gate /etc/vdisk-relay.allow-gadget

  if [ "$CONFIGURE_SOURCE" = "1" ] && [ "$CONFIGURE_TELEGRAM" = "1" ]; then
    write_gate /etc/vdisk-relay.allow-watch
    write_gate /etc/vdisk-relay.allow-trigger
    write_gate /etc/vdisk-relay.allow-sync
    write_gate /etc/vdisk-relay.allow-health-reboot
    write_gate /etc/vdisk-relay.allow-boot-notify
  else
    warn "Sync, health, and boot-notify gates were skipped because source or Telegram configuration is incomplete."
  fi

  if [ "$CONFIGURE_ARCHIVE" = "1" ]; then
    write_gate /etc/vdisk-relay.allow-archive
  else
    warn "Archive gate skipped."
  fi

  if [ "$ENABLE_NETWORK_GUARDIAN" = "1" ]; then
    write_gate /etc/vdisk-relay.allow-network-guardian
  fi

  ok "Created selected live gates"
else
  warn "No live gates created. Runtime services stay disabled until gates are enabled by installer or WebUI."
fi

echo
echo "=== Verification ==="
if [ -x /usr/local/sbin/vdisk-relay ]; then
  /usr/local/sbin/vdisk-relay config | grep -E 'IMAGE_FILE|DATA_ROOT|ARCHIVE_RSYNC|LIVE_QUIET|BOOT_NOTIFY' || true
  /usr/local/sbin/vdisk-relay status-lights || true
else
  warn "/usr/local/sbin/vdisk-relay is not installed yet; run deploy/bookworm/install.sh after the wizard."
fi

ok "Wizard finished"
