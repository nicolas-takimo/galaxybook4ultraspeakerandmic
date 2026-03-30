#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOPBACK_CAPS_FILE="/sys/module/v4l2loopback/parameters/exclusive_caps"

loopback_caps_ok() {
  [[ -r "${LOOPBACK_CAPS_FILE}" ]] || return 1
  local caps
  caps="$(cat "${LOOPBACK_CAPS_FILE}")"
  [[ -n "${caps}" && "${caps}" == Y* ]]
}

if ! loopback_caps_ok; then
  echo "v4l2loopback is not in webcam mode. Running fix script..."
  "${SCRIPT_DIR}/fix-camera-loopback.sh"
fi

systemctl --user start camera-relay.service
sleep 2
systemctl --user --no-pager --full status camera-relay.service | sed -n '1,20p'
