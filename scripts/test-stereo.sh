#!/usr/bin/env bash
set -euo pipefail

echo "Running stereo test."
echo "Expected order:"
echo "  Front Left"
echo "  Front Right"
echo

speaker-test -c 2 -t wav -l 1
