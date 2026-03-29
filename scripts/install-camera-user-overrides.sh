#!/usr/bin/env bash
set -euo pipefail

USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
PIPEWIRE_DROPIN_DIR="${USER_SYSTEMD_DIR}/pipewire.service.d"
WIREPLUMBER_DROPIN_DIR="${USER_SYSTEMD_DIR}/wireplumber.service.d"
PIPEWIRE_SOFTISP_FILE="${PIPEWIRE_DROPIN_DIR}/90-libcamera-softisp.conf"
WIREPLUMBER_SOFTISP_FILE="${WIREPLUMBER_DROPIN_DIR}/90-libcamera-softisp.conf"
CAMERA_RELAY_SERVICE="${USER_SYSTEMD_DIR}/camera-relay.service"
WP_V4L2_RULE="/etc/wireplumber/wireplumber.conf.d/50-disable-ipu6-v4l2.conf"

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

TMP_RULE="$(mktemp)"
cat > "${TMP_RULE}" <<'EOF'
# Disable raw Intel IPU6 V4L2 devices in PipeWire.
# PipeWire apps should use the libcamera source instead.
# Keep the Camera Relay available only for direct V4L2 apps, not as a PipeWire node.
monitor.v4l2.rules = [
  {
    matches = [
      { device.api = "v4l2", api.v4l2.cap.driver = "isys" }
      { device.api = "v4l2", api.v4l2.cap.card = "ipu6" }
      { device.name = "~v4l2_device\\.pci-0000_00_05\\.0" }
    ]
    actions = {
      update-props = {
        device.disabled = true
        node.disabled = true
        priority.session = 0
      }
    }
  }
  {
    matches = [
      { device.api = "v4l2", api.v4l2.cap.driver = "v4l2 loopback", api.v4l2.cap.card = "Camera Relay" }
    ]
    actions = {
      update-props = {
        device.disabled = true
        node.disabled = true
        priority.session = 0
      }
    }
  }
]
EOF

sudo install -m 0644 "${TMP_RULE}" "${WP_V4L2_RULE}"
rm -f "${TMP_RULE}"

echo "Reloading user systemd..."
systemctl --user daemon-reload
systemctl --user disable --now camera-relay.service >/dev/null 2>&1 || true
systemctl --user restart wireplumber pipewire pipewire-pulse

echo
echo "Camera user overrides installed."
echo "Services updated:"
echo "  ${PIPEWIRE_SOFTISP_FILE}"
echo "  ${WIREPLUMBER_SOFTISP_FILE}"
echo "  ${CAMERA_RELAY_SERVICE}"
echo "  ${WP_V4L2_RULE}"
echo
echo "PipeWire apps should use the internal camera directly after login."
echo "If you need a V4L2 relay for legacy apps, run:"
echo "  systemctl --user start camera-relay.service"
