#!/usr/bin/env bash
set -euo pipefail

echo "Starting MAX98390 runtime setup service..."
sudo systemctl start max98390-hda-i2c-setup.service

echo
echo "Service status:"
systemctl status max98390-hda-i2c-setup.service --no-pager --lines=20

echo
echo "Recent MAX98390 kernel messages:"
journalctl -b -k | rg -i 'max98390' | tail -n 20 || true
