#!/usr/bin/env bash
set -euo pipefail

SERVICE="camera-relay.service"
SESSION_UNITS=(
  pipewire.service
  pipewire-pulse.service
  wireplumber.service
  xdg-desktop-portal.service
  xdg-desktop-portal-gnome.service
)

loopback_caps_value() {
  local caps_file="/sys/module/v4l2loopback/parameters/exclusive_caps"
  [[ -r "${caps_file}" ]] || return 1
  cat "${caps_file}"
}

loopback_caps_ok() {
  local caps
  caps="$(loopback_caps_value 2>/dev/null || true)"
  [[ -n "${caps}" && "${caps}" == Y* ]]
}

status() {
  systemctl --user is-active "${SERVICE}" 2>/dev/null || true
}

wait_for_state() {
  local wanted="$1"
  local i current
  for i in {1..20}; do
    current="$(status)"
    if [[ "${current}" == "${wanted}" ]]; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

wait_for_device() {
  local i
  for i in {1..20}; do
    if timeout 2 ffprobe -hide_banner -f v4l2 -show_streams /dev/video0 >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

refresh_session_stack() {
  systemctl --user restart "${SESSION_UNITS[@]}"
  sleep 2
}

notify() {
  notify-send "Camera Relay" "$1" >/dev/null 2>&1 || true
}

show_loopback_fix_needed() {
  local msg
  msg=$'The v4l2loopback module is loaded in a mode that browsers reject.\n\nRun this command in a regular terminal:\n\n~/.local/bin/fix-camera-loopback\n\nThen open Camera Relay again.'
  notify "Run ~/.local/bin/fix-camera-loopback"
  zenity --error --title="Camera Relay" --width=520 --text="${msg}" >/dev/null 2>&1 || true
}

launch_fix_terminal() {
  local cmd='~/.local/bin/fix-camera-loopback; echo; echo "Done. You can close this window."; read -r'

  if command -v ptyxis >/dev/null 2>&1; then
    ptyxis -s -T "Camera Relay Fix" -- bash -lc "${cmd}" >/dev/null 2>&1 &
    return 0
  fi

  if command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal -- bash -lc "${cmd}" >/dev/null 2>&1 &
    return 0
  fi

  if command -v xterm >/dev/null 2>&1; then
    xterm -e bash -lc "${cmd}" >/dev/null 2>&1 &
    return 0
  fi

  return 1
}

wait_caps_ok() {
  local i
  for i in {1..120}; do
    if loopback_caps_ok; then
      return 0
    fi
    sleep 1
  done
  return 1
}

auto_fix_loopback() {
  if loopback_caps_ok; then
    return 0
  fi

  notify "Fixing camera module..."

  # Works when this script is launched from a terminal with sudo prompt.
  if ~/.local/bin/fix-camera-loopback >/tmp/camera-relay-fix.log 2>&1; then
    loopback_caps_ok && return 0
  fi

  # When launched from GUI, open a terminal for sudo password entry.
  if launch_fix_terminal; then
    wait_caps_ok && return 0
  fi

  return 1
}

start_relay() {
  local attempt

  if ! loopback_caps_ok; then
    if ! auto_fix_loopback; then
      show_loopback_fix_needed
      exit 1
    fi
  fi

  for attempt in 1 2; do
    refresh_session_stack
    systemctl --user reset-failed "${SERVICE}" >/dev/null 2>&1 || true
    systemctl --user stop "${SERVICE}" >/dev/null 2>&1 || true
    sleep 0.5
    systemctl --user start "${SERVICE}"
    if wait_for_state active && wait_for_device; then
      notify "Camera enabled. Open your app and select Camera Relay."
      return 0
    fi
  done

  notify "Failed to enable camera."
  exit 1
}

stop_relay() {
  systemctl --user stop "${SERVICE}" || true
  wait_for_state inactive || true
  notify "Camera disabled."
}

gui() {
  local current choice
  current="$(status)"
  choice="$(
    zenity --list \
      --title="Camera Relay" \
      --text="Current status: ${current}" \
      --column="Action" \
      "Enable camera" \
      "Disable camera" \
      --height=240 \
      --width=320
  )" || exit 0

  case "${choice}" in
    "Enable camera") start_relay ;;
    "Disable camera") stop_relay ;;
  esac
}

case "${1:-gui}" in
  start) start_relay ;;
  stop) stop_relay ;;
  status) status ;;
  toggle)
    if [[ "$(status)" == "active" ]]; then
      stop_relay
    else
      start_relay
    fi
    ;;
  gui) gui ;;
  *)
    echo "Usage: $0 [start|stop|status|toggle|gui]" >&2
    exit 1
    ;;
esac
