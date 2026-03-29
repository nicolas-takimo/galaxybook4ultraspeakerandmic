#!/usr/bin/env bash
set -euo pipefail

OUT_FILE="${1:-${HOME}/Imagens/galaxy-book4-camera-test.jpg}"

mkdir -p "$(dirname "${OUT_FILE}")"

STARTED_RELAY=0
if ! systemctl --user is-active --quiet camera-relay.service; then
  systemctl --user start camera-relay.service
  STARTED_RELAY=1
  sleep 2
fi

echo "Capturing one frame from /dev/video0 to ${OUT_FILE}..."
ffmpeg -hide_banner -loglevel error -f v4l2 -i /dev/video0 -vf "select=gte(n\,20)" -frames:v 1 -update 1 -y "${OUT_FILE}"

if [ "${STARTED_RELAY}" -eq 1 ]; then
  systemctl --user stop camera-relay.service
fi

echo
echo "Frame written to: ${OUT_FILE}"
