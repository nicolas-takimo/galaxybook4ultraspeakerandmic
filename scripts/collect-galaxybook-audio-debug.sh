#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/debug/$(date +%Y%m%d-%H%M%S)"

mkdir -p "${OUT_DIR}"

uname -a > "${OUT_DIR}/uname.txt"
cat /etc/os-release > "${OUT_DIR}/os-release.txt"
cat /sys/devices/virtual/dmi/id/product_name > "${OUT_DIR}/product_name.txt"
cat /sys/devices/virtual/dmi/id/board_name > "${OUT_DIR}/board_name.txt"

lspci -nn > "${OUT_DIR}/lspci.txt"
lsmod > "${OUT_DIR}/lsmod.txt"
dkms status > "${OUT_DIR}/dkms-status.txt" || true
aplay -l > "${OUT_DIR}/aplay-l.txt" || true
arecord -l > "${OUT_DIR}/arecord-l.txt" || true
amixer -c 0 scontents > "${OUT_DIR}/amixer-scontents.txt" || true
wpctl status > "${OUT_DIR}/wpctl-status.txt" || true
pactl list short sinks > "${OUT_DIR}/pactl-sinks.txt" || true
pactl list short sources > "${OUT_DIR}/pactl-sources.txt" || true
camera-relay status > "${OUT_DIR}/camera-relay-status.txt" || true
cam --list > "${OUT_DIR}/cam-list.txt" || true
systemctl --user status camera-relay.service pipewire.service wireplumber.service --no-pager > "${OUT_DIR}/camera-services.txt" || true
journalctl -b -k > "${OUT_DIR}/journal-kernel.txt" || true
journalctl -b -u max98390-hda-i2c-setup.service > "${OUT_DIR}/journal-max98390-service.txt" || true
journalctl -b --user -u camera-relay.service --no-pager > "${OUT_DIR}/journal-camera-relay.txt" || true
grep -R "MAX98390" /sys/bus/i2c/devices/*/name > "${OUT_DIR}/max98390-i2c.txt" 2>/dev/null || true
ls -l /dev/video0 > "${OUT_DIR}/video0.txt" 2>/dev/null || true

echo "Debug bundle written to: ${OUT_DIR}"
