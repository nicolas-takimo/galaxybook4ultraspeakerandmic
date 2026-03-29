#!/usr/bin/env bash
set -euo pipefail

systemctl --user stop camera-relay.service
echo "camera-relay.service stopped."
