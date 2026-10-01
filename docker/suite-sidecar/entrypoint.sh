#!/usr/bin/env bash
# Mounts the Suite Studios team drive at $SUITE_MOUNT and keeps it mounted.
set -euo pipefail

: "${SUITE_USERNAME:?SUITE_USERNAME is required}"
: "${SUITE_PASSWORD:?SUITE_PASSWORD is required}"
MOUNT=${SUITE_MOUNT:-/mnt/suite/drive}
CONFIG=/root/.SuiteStudios/App/.config.json
READY=/tmp/ready

fuse_mounts_under() {
  # Reads mountinfo instead of stat'ing paths, which hangs on a dead FUSE mount.
  awk -v base="$1" 'index($5, base) == 1 && / - fuse/ { print $5 }' /proc/self/mountinfo | sort -r
}

unmount_all() {
  local m
  for m in $(fuse_mounts_under "$(dirname "$MOUNT")"); do
    echo "unmounting $m"
    umount -l "$m" || true
  done
}

is_mounted() {
  fuse_mounts_under "$MOUNT" | grep -qx "$MOUNT"
}

write_config() {
  # Suite only accepts `config set` while running, so pre-seed the file it writes.
  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<EOF
{
  "BASE_FUSE_MOUNT_POINT": "$MOUNT",
  "FUSE_ALLOW_OTHER": "true",
  "MAX_MEMORY_CACHE_SIZE_GIGABYTES": "${SUITE_MEM_CACHE_GB:-2}",
  "SATURN_DISK_CACHE_SIZE_IN_GIGABYTES": ${SUITE_DISK_CACHE_GB:-40}
}
EOF
}

shutdown() {
  echo "SIGTERM: flushing uploads and stopping suitefs"
  rm -f "$READY"
  timeout "${SUITE_STOP_TIMEOUT:-270}" suite stop --wait || echo "suite stop failed or timed out"
  unmount_all
  exit 0
}

trap shutdown TERM INT

unmount_all   # leftovers from a crashed previous run
write_config
mkdir -p "$MOUNT"

suite start -u "$SUITE_USERNAME"
for _ in $(seq 60); do
  is_mounted && break
  sleep 1
done
is_mounted || { echo "suitefs did not mount $MOUNT" >&2; exit 1; }
touch "$READY"
echo "mounted $MOUNT"

# `sleep & wait` lets the trap fire immediately instead of after the sleep.
while timeout 20 suite status >/dev/null 2>&1 && is_mounted; do
  sleep 30 & wait $!
done
echo "suitefs died or lost its mount; exiting for a clean restart" >&2
unmount_all
exit 1
