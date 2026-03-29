#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_DIR="${ROOT_DIR}/upstream"
REPO_URL="https://github.com/Andycodeman/samsung-galaxy-book4-linux-fixes"
REPO_DIR="${UPSTREAM_DIR}/samsung-galaxy-book4-linux-fixes"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

require_cmd git
require_cmd sudo

echo "== Galaxy Book4 Ultra speaker fix installer =="

if command -v dnf >/dev/null 2>&1; then
  echo "Installing prerequisites with dnf..."
  sudo dnf install -y dkms kernel-devel i2c-tools
else
  echo "This helper currently automates Fedora/DNF only." >&2
  echo "Install dependencies manually, then run the upstream installer." >&2
  exit 1
fi

mkdir -p "${UPSTREAM_DIR}"

if [ -d "${REPO_DIR}/.git" ]; then
  echo "Updating existing upstream checkout..."
  git -C "${REPO_DIR}" pull --ff-only
else
  echo "Cloning upstream project..."
  git clone --depth 1 "${REPO_URL}" "${REPO_DIR}"
fi

echo "Running upstream speaker installer..."
cd "${REPO_DIR}/speaker-fix"
sudo ./install.sh

echo "Starting runtime amplifier setup..."
sudo systemctl start max98390-hda-i2c-setup.service

echo
echo "Installation finished."
echo "Run: ${ROOT_DIR}/scripts/check-audio-status.sh"
echo "Then test: ${ROOT_DIR}/scripts/test-stereo.sh"
