#!/usr/bin/env bash
set -euo pipefail

systemctl --user start camera-relay.service
camera-relay status
