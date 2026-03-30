#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
USER_BIN_DIR="${HOME}/.local/bin"
USER_APPS_DIR="${HOME}/.local/share/applications"
PIPEWIRE_DROPIN_DIR="${USER_SYSTEMD_DIR}/pipewire.service.d"
WIREPLUMBER_DROPIN_DIR="${USER_SYSTEMD_DIR}/wireplumber.service.d"
USER_WIREPLUMBER_RULE_DIR="${HOME}/.config/wireplumber/wireplumber.conf.d"
PIPEWIRE_SOFTISP_FILE="${PIPEWIRE_DROPIN_DIR}/90-libcamera-softisp.conf"
WIREPLUMBER_SOFTISP_FILE="${WIREPLUMBER_DROPIN_DIR}/90-libcamera-softisp.conf"
CAMERA_RELAY_SERVICE="${USER_SYSTEMD_DIR}/camera-relay.service"
WP_V4L2_RULE="/etc/wireplumber/wireplumber.conf.d/50-disable-ipu6-v4l2.conf"
BROKEN_LIBCAMERA_RULE="${USER_WIREPLUMBER_RULE_DIR}/60-disable-broken-libcamera.conf"
RELAY_FIX_SCRIPT="${USER_BIN_DIR}/fix-camera-loopback"
RELAY_CONTROL_SCRIPT="${USER_BIN_DIR}/camera-relay-control"
RELAY_DESKTOP_FILE="${USER_APPS_DIR}/camera-relay.desktop"
RELAY_SYSTRAY_OVERRIDE="${USER_APPS_DIR}/camera-relay-systray.desktop"

mkdir -p "${PIPEWIRE_DROPIN_DIR}" "${WIREPLUMBER_DROPIN_DIR}" "${USER_WIREPLUMBER_RULE_DIR}" "${USER_BIN_DIR}" "${USER_APPS_DIR}"

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
Description=Camera Relay (explicit libcamera to v4l2loopback pipeline)
After=pipewire.service wireplumber.service

[Service]
Type=simple
ExecStart=/usr/bin/bash -lc 'exec gst-launch-1.0 -e libcamerasrc ! videoconvert ! video/x-raw,format=YUY2 ! v4l2sink device=/dev/video0 io-mode=mmap sync=false'
Restart=on-failure
RestartSec=5
Environment=LIBCAMERA_IPA_MODULE_PATH=/usr/lib64/libcamera
Environment=GST_PLUGIN_PATH=/usr/local/lib64/gstreamer-1.0
Environment=LD_LIBRARY_PATH=/usr/local/lib64
Environment=LIBCAMERA_SOFTISP_MODE=cpu

[Install]
WantedBy=default.target
EOF

TMP_RULE="$(mktemp)"
cat > "${TMP_RULE}" <<'EOF'
# Disable raw Intel IPU6 V4L2 devices in PipeWire.
# Keep Camera Relay visible as the stable camera source for apps.
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
]
EOF

sudo install -m 0644 "${TMP_RULE}" "${WP_V4L2_RULE}"
rm -f "${TMP_RULE}"

cat > "${BROKEN_LIBCAMERA_RULE}" <<'EOF'
monitor.libcamera.rules = [
  {
    matches = [
      { node.name = "libcamera_input.__SB_.PC00.LNK0" }
    ]
    actions = {
      update-props = {
        node.disabled = true
        priority.session = 0
      }
    }
  }
]
EOF

install -m 0755 "${SCRIPT_DIR}/fix-camera-loopback.sh" "${RELAY_FIX_SCRIPT}"
install -m 0755 "${SCRIPT_DIR}/camera-relay-control.sh" "${RELAY_CONTROL_SCRIPT}"

cat > "${RELAY_DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Camera Relay
Comment=Enable or disable the virtual camera
Exec=${RELAY_CONTROL_SCRIPT}
Icon=camera-web
Terminal=false
Categories=AudioVideo;Video;
StartupNotify=true
EOF

cat > "${RELAY_SYSTRAY_OVERRIDE}" <<'EOF'
[Desktop Entry]
Type=Application
Name=Camera Relay
Hidden=true
EOF

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
echo "  ${BROKEN_LIBCAMERA_RULE}"
echo "  ${RELAY_FIX_SCRIPT}"
echo "  ${RELAY_CONTROL_SCRIPT}"
echo "  ${RELAY_DESKTOP_FILE}"
echo
echo "PipeWire apps should use Camera Relay when ele estiver ligado."
echo "Para ligar o relay manualmente, rode:"
echo "  ~/.local/bin/camera-relay-control start"
echo
echo "If browser camera disappears after reboot, run:"
echo "  ~/.local/bin/fix-camera-loopback"
