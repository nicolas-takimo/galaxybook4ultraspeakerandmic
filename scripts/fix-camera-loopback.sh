#!/usr/bin/env bash
set -euo pipefail

stop_camera_users() {
  systemctl --user stop camera-relay.service >/dev/null 2>&1 || true

  # Common camera clients that may keep /dev/video0 busy.
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
