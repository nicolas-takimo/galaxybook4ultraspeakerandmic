#!/usr/bin/env bash
set -euo pipefail

USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
USER_BIN_DIR="${HOME}/.local/bin"
PIPEWIRE_DROPIN_DIR="${USER_SYSTEMD_DIR}/pipewire.service.d"
WIREPLUMBER_DROPIN_DIR="${USER_SYSTEMD_DIR}/wireplumber.service.d"
USER_WIREPLUMBER_RULE_DIR="${HOME}/.config/wireplumber/wireplumber.conf.d"
PIPEWIRE_SOFTISP_FILE="${PIPEWIRE_DROPIN_DIR}/90-libcamera-softisp.conf"
WIREPLUMBER_SOFTISP_FILE="${WIREPLUMBER_DROPIN_DIR}/90-libcamera-softisp.conf"
CAMERA_RELAY_SERVICE="${USER_SYSTEMD_DIR}/camera-relay.service"
WP_V4L2_RULE="/etc/wireplumber/wireplumber.conf.d/50-disable-ipu6-v4l2.conf"
BROKEN_LIBCAMERA_RULE="${USER_WIREPLUMBER_RULE_DIR}/60-disable-broken-libcamera.conf"
RELAY_FIX_SCRIPT="${USER_BIN_DIR}/fix-camera-loopback"

mkdir -p "${PIPEWIRE_DROPIN_DIR}" "${WIREPLUMBER_DROPIN_DIR}" "${USER_WIREPLUMBER_RULE_DIR}" "${USER_BIN_DIR}"

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

cat > "${RELAY_FIX_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

stop_camera_users() {
  systemctl --user stop camera-relay.service >/dev/null 2>&1 || true
  pkill -f 'camera-relay-monitor|gst-launch-1.0.*libcamerasrc' >/dev/null 2>&1 || true
  pkill -f '/app/brave/brave|/app/vivaldi/vivaldi|/usr/lib64/firefox/firefox' >/dev/null 2>&1 || true
  pkill -f '/usr/share/discord/Discord|teams|zoom|obs|snapshot' >/dev/null 2>&1 || true
}

wait_video0_free() {
  local i
  for i in {1..20}; do
    if ! fuser /dev/video0 >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

echo "Stopping relay and camera apps that may hold /dev/video0..."
stop_camera_users

if ! wait_video0_free; then
  echo
  echo "There is still a process using /dev/video0."
  echo "Close browser/call apps and run again."
  echo
  echo "Current holders:"
  fuser -v /dev/video0 || true
  exit 1
fi

echo "Reloading v4l2loopback in webcam mode (exclusive_caps=1)..."
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback devices=1 video_nr=0 exclusive_caps=1 card_label="Camera Relay"

echo
echo "Restarting user camera session stack..."
systemctl --user restart \
  pipewire.service \
  pipewire-pulse.service \
  wireplumber.service \
  xdg-desktop-portal.service \
  xdg-desktop-portal-gnome.service \
  camera-relay.service

echo
echo "Current state:"
cat /sys/module/v4l2loopback/parameters/exclusive_caps
if command -v rg >/dev/null 2>&1; then
  udevadm info -q property -n /dev/video0 | rg '^ID_V4L_CAPABILITIES=' || true
else
  udevadm info -q property -n /dev/video0 | grep '^ID_V4L_CAPABILITIES=' || true
fi

echo
echo "Close and reopen your browser/app."
EOF

chmod +x "${RELAY_FIX_SCRIPT}"

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
echo
echo "PipeWire apps should use Camera Relay when ele estiver ligado."
echo "Para ligar o relay manualmente, rode:"
echo "  systemctl --user start camera-relay.service"
echo
echo "If browser camera disappears after reboot, run:"
echo "  ~/.local/bin/fix-camera-loopback"
