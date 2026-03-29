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
echo "== Default devices =="
printf "Default sink: "
pactl get-default-sink 2>/dev/null || true
printf "Default source: "
pactl get-default-source 2>/dev/null || true

echo
echo "== DKMS =="
dkms status | rg 'max98390|sof|audio' || true

echo
echo "== Loaded modules =="
lsmod | rg 'max98390|snd_hda_scodec|snd_sof|snd_hda' || true

echo
echo "== I2C MAX98390 devices =="
grep -R "MAX98390" /sys/bus/i2c/devices/*/name 2>/dev/null || true

echo
echo "== Service log =="
journalctl -b -u max98390-hda-i2c-setup.service --no-pager -n 10 2>/dev/null || true

echo
echo "== ALSA playback devices =="
aplay -l 2>/dev/null || true

echo
echo "== ALSA capture devices =="
arecord -l 2>/dev/null || true
