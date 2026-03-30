#!/usr/bin/env bash
set -euo pipefail

MODPROBE_CONF="/etc/modprobe.d/99-camera-relay-loopback.conf"
SERVICE_FILE="/etc/systemd/system/camera-loopback-bootfix.service"

echo "Installing persistent v4l2loopback options..."
sudo tee "${MODPROBE_CONF}" >/dev/null <<'EOF'
options v4l2loopback devices=1 video_nr=0 exclusive_caps=1 card_label="Camera Relay"
EOF

echo "Installing boot-time loopback fix service..."
sudo tee "${SERVICE_FILE}" >/dev/null <<'EOF'
[Unit]
Description=Camera loopback boot fix (force browser-compatible mode)
After=systemd-modules-load.service
Before=graphical.target

[Service]
Type=oneshot
ExecStart=-/usr/sbin/modprobe -r v4l2loopback
ExecStart=/usr/sbin/modprobe v4l2loopback devices=1 video_nr=0 exclusive_caps=1 card_label=Camera Relay
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable --now camera-loopback-bootfix.service

echo
echo "Boot-fix service status:"
systemctl --no-pager --full status camera-loopback-bootfix.service | sed -n '1,30p'

echo
echo "Done. From now on, reboot should no longer require manual loopback fix."
