#!/usr/bin/env bash
set -euo pipefail

USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
PIPEWIRE_DROPIN_DIR="${USER_SYSTEMD_DIR}/pipewire.service.d"
WIREPLUMBER_DROPIN_DIR="${USER_SYSTEMD_DIR}/wireplumber.service.d"
PIPEWIRE_SOFTISP_FILE="${PIPEWIRE_DROPIN_DIR}/90-libcamera-softisp.conf"
WIREPLUMBER_SOFTISP_FILE="${WIREPLUMBER_DROPIN_DIR}/90-libcamera-softisp.conf"
CAMERA_RELAY_SERVICE="${USER_SYSTEMD_DIR}/camera-relay.service"

mkdir -p "${PIPEWIRE_DROPIN_DIR}" "${WIREPLUMBER_DROPIN_DIR}"

cat > "${PIPEWIRE_SOFTISP_FILE}" <<'EOF'
[Service]
Environment=LIBCAMERA_SOFTISP_MODE=cpu
EOF

cat > "${WIREPLUMBER_SOFTISP_FILE}" <<'EOF'
[Service]
Environment=LIBCAMERA_SOFTISP_MODE=cpu
EOF

mkdir -p "${USER_SYSTEMD_DIR}"

cat > "${CAMERA_RELAY_SERVICE}" <<'EOF'
[Unit]
Description=Camera Relay (on-demand libcamera to v4l2loopback)
After=pipewire.service wireplumber.service

[Service]
Type=simple
ExecStart=/usr/local/bin/camera-relay start --on-demand
ExecStop=/usr/local/bin/camera-relay stop
Restart=on-failure
RestartSec=5
Environment=LIBCAMERA_IPA_MODULE_PATH=/usr/lib64/libcamera
Environment=GST_PLUGIN_PATH=/usr/local/lib64/gstreamer-1.0
Environment=LD_LIBRARY_PATH=/usr/local/lib64
Environment=LIBCAMERA_SOFTISP_MODE=cpu
Environment="RELAY_COLOR_FILTER=video/x-raw,format=I420 ! videomedian filtersize=5 lum-only=true ! videoconvert"

[Install]
WantedBy=default.target
EOF

echo "Reloading user systemd..."
systemctl --user daemon-reload
systemctl --user enable --now camera-relay.service
systemctl --user restart wireplumber pipewire pipewire-pulse camera-relay.service

echo
echo "Camera user overrides installed."
echo "Services updated:"
echo "  ${PIPEWIRE_SOFTISP_FILE}"
echo "  ${WIREPLUMBER_SOFTISP_FILE}"
echo "  ${CAMERA_RELAY_SERVICE}"
