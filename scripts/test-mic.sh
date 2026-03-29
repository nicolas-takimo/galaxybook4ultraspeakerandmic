#!/usr/bin/env bash
set -euo pipefail

OUT_FILE="${1:-/tmp/galaxy-book4-ultra-mic-test.wav}"

echo "Recording 5 seconds from the default source to ${OUT_FILE}..."
arecord -f cd -d 5 "${OUT_FILE}"

echo
echo "Playing recorded sample..."
aplay "${OUT_FILE}"
