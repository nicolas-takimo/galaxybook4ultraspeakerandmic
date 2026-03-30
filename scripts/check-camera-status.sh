#!/usr/bin/env bash
set -euo pipefail

echo "== Machine =="
printf "Model: "
cat /sys/devices/virtual/dmi/id/product_name
printf "Board: "
cat /sys/devices/virtual/dmi/id/board_name

echo
echo "== Kernel =="
uname -r

echo
echo "== Camera relay service =="
systemctl --user --no-pager --full status camera-relay.service 2>/dev/null | sed -n '1,40p' || true

echo
echo "== User services =="
systemctl --user --no-pager --full status pipewire.service wireplumber.service 2>/dev/null | sed -n '1,120p' || true

echo
echo "== Video nodes in PipeWire =="
wpctl status | sed -n '/Video/,/Settings/p' | sed -n '1,160p' || true

echo
echo "== libcamera =="
cam --list 2>/dev/null || true

echo
echo "== Relay device =="
ls -l /dev/video0 2>/dev/null || true

echo
echo "== v4l2loopback mode =="
cat /sys/module/v4l2loopback/parameters/exclusive_caps 2>/dev/null || echo "v4l2loopback not loaded"
for dev in /dev/video0 /dev/video1; do
  [ -e "${dev}" ] || continue
  echo "--- ${dev}"
  udevadm info -q property -n "${dev}" | grep -E '^ID_V4L_PRODUCT=|^ID_V4L_CAPABILITIES=' || true
done

echo
echo "== Relevant kernel log =="
if command -v rg >/dev/null 2>&1; then
  journalctl -b -k --no-pager | rg -i 'ov02c10|ipu6|ivsc|camera' | tail -n 40 || true
else
  journalctl -b -k --no-pager | grep -Ei 'ov02c10|ipu6|ivsc|camera' | tail -n 40 || true
fi
