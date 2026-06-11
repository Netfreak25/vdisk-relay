#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_PACKAGES=0
CONFIGURE_GADGET=0
NO_APT_UPDATE=0

PACKAGES=(
  bash
  coreutils
  util-linux
  fdisk
  mount
  systemd
  rsync
  curl
  ca-certificates
  python3
  grep
  sed
  gawk
  findutils
  procps
  kmod
  iproute2
  inotify-tools
  dosfstools
  cron
  sudo
  git
  ffmpeg
  network-manager
  iputils-ping
)

COMMANDS=(
  bash
  systemctl
  rsync
  curl
  python3
  losetup
  mount
  umount
  mountpoint
  findmnt
  flock
  timeout
  logger
  modprobe
  lsmod
  getent
  awk
  sed
  grep
  find
  stat
  cmp
  cp
  mv
  rm
  date
  sleep
  mkdir
  touch
  crontab
  inotifywait
  fdisk
  mkfs.vfat
  dd
  reboot
  ffmpeg
  nmcli
  ping
)

KERNEL_MODULES=(
  dwc2
  libcomposite
  g_mass_storage
)

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage: $0 [OPTIONS]

Checks/installs runtime dependencies for vdisk-relay.

Options:
  --check              only check
  --install-packages   install Debian/Ubuntu/Raspbian packages
  --configure-gadget   set Raspberry Pi USB gadget boot configuration
  --all                install packages, configure gadget, and check
  --no-apt-update      skip apt-get update
  -h, --help           show help

Examples:
  $0 --check
  $0 --install-packages
  $0 --configure-gadget
  $0 --all
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) ;;
    --install-packages) INSTALL_PACKAGES=1 ;;
    --configure-gadget) CONFIGURE_GADGET=1 ;;
    --all) INSTALL_PACKAGES=1; CONFIGURE_GADGET=1 ;;
    --no-apt-update) NO_APT_UPDATE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

[ "$(id -u)" -eq 0 ] || fail "Must run as root"

pkg_installed() {
  dpkg-query -W -f='${db:State-State}' "$1" 2>/dev/null | grep -qx installed
}

check_packages() {
  local missing=0
  local p

  echo "=== Package check ==="

  for p in "${PACKAGES[@]}"; do
    if pkg_installed "$p"; then
      ok "Package installed: $p"
    else
      echo "[MISS] Package missing: $p"
      missing=1
    fi
  done

  return "$missing"
}

install_packages() {
  local missing=()
  local p

  for p in "${PACKAGES[@]}"; do
    pkg_installed "$p" || missing+=("$p")
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    ok "All packages already installed"
    return 0
  fi

  echo "=== Installing packages ==="
  printf '%s\n' "${missing[@]}"

  export DEBIAN_FRONTEND=noninteractive

  if [ "$NO_APT_UPDATE" -ne 1 ]; then
    apt-get update
  fi

  apt-get install -y "${missing[@]}"
  ok "Package installation completed"
}

check_commands() {
  local missing=0
  local c

  echo
  echo "=== Command-Check ==="

  for c in "${COMMANDS[@]}"; do
    if command -v "$c" >/dev/null 2>&1; then
      ok "Command available: $c -> $(command -v "$c")"
    else
      echo "[MISS] Command missing: $c"
      missing=1
    fi
  done

  return "$missing"
}

module_available() {
  local m="$1"

  modinfo "$m" >/dev/null 2>&1 && return 0
  grep -qw "$m" /proc/modules 2>/dev/null && return 0
  [ -d "/sys/module/$m" ] && return 0

  return 1
}

check_kernel_modules() {
  local missing=0
  local m

  echo
  echo "=== Kernel module check ==="

  for m in "${KERNEL_MODULES[@]}"; do
    if module_available "$m"; then
      ok "Kernel module available: $m"
    else
      echo "[MISS] Kernel module missing/not visible: $m"
      missing=1
    fi
  done

  return "$missing"
}

detect_boot_config() {
  if [ -f /boot/firmware/config.txt ]; then
    echo /boot/firmware/config.txt
    return 0
  fi

  if [ -f /boot/config.txt ]; then
    echo /boot/config.txt
    return 0
  fi

  return 1
}

configure_gadget_boot() {
  local cfg

  echo
  echo "=== USB gadget boot configuration ==="

  cfg="$(detect_boot_config)" || fail "No Raspberry Pi boot config found"

  cp -a "$cfg" "${cfg}.bak.vdisk-relay.$(date +%Y%m%d-%H%M%S)"
  ok "Backup created: ${cfg}.bak.vdisk-relay.*"

  if grep -Eq '^[[:space:]]*dtoverlay=dwc2([[:space:]]|$)' "$cfg"; then
    ok "dtoverlay=dwc2 already set in $cfg"
  else
    {
      echo
      echo "# vdisk-relay USB gadget"
      echo "dtoverlay=dwc2"
    } >> "$cfg"
    ok "dtoverlay=dwc2 added to $cfg"
  fi

  cat > /etc/modules-load.d/vdisk-relay.conf <<'MODULES'
dwc2
libcomposite
MODULES

  chmod 0644 /etc/modules-load.d/vdisk-relay.conf
  ok "/etc/modules-load.d/vdisk-relay.conf written"

  modprobe dwc2 >/dev/null 2>&1 && ok "dwc2 loadable" || warn "dwc2 could not be loaded right now"
  modprobe libcomposite >/dev/null 2>&1 && ok "libcomposite loadable" || warn "libcomposite could not be loaded right now"

  warn "g_mass_storage is not loaded via modules-load; startup is handled by vdisk-relay-gadget-live.service"
}

check_gadget_config() {
  local cfg

  echo
  echo "=== Gadget configuration check ==="

  cfg="$(detect_boot_config 2>/dev/null || true)"

  if [ -n "$cfg" ] && grep -Eq '^[[:space:]]*dtoverlay=dwc2([[:space:]]|$)' "$cfg"; then
    ok "Boot config contains dtoverlay=dwc2: $cfg"
  else
    warn "dtoverlay=dwc2 not found in boot config"
  fi

  if [ -f /etc/modules-load.d/vdisk-relay.conf ]; then
    ok "modules-load config available: /etc/modules-load.d/vdisk-relay.conf"
  else
    warn "modules-load config missing: /etc/modules-load.d/vdisk-relay.conf"
  fi

  lsmod | grep -E 'dwc2|libcomposite|g_mass_storage|usb_f_mass_storage' || true
}

FAILED=0

if [ "$INSTALL_PACKAGES" -eq 1 ]; then
  install_packages || FAILED=1
fi

if [ "$CONFIGURE_GADGET" -eq 1 ]; then
  configure_gadget_boot || FAILED=1
fi

check_packages || FAILED=1
check_commands || FAILED=1
check_kernel_modules || FAILED=1
check_gadget_config || true

echo

if [ "$FAILED" -eq 0 ]; then
  ok "Dependency check completed: all green"
  exit 0
fi

fail "Dependency check completed: at least one item is missing"
