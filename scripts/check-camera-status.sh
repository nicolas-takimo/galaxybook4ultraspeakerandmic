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
echo "== Camera relay =="
camera-relay status 2>/dev/null || true

echo
echo "== User services =="
systemctl --user --no-pager --full status camera-relay.service pipewire.service wireplumber.service 2>/dev/null | sed -n '1,120p' || true

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
echo "== Relevant kernel log =="
journalctl -b -k --no-pager | rg -i 'ov02c10|ipu6|ivsc|camera' | tail -n 40 || true
