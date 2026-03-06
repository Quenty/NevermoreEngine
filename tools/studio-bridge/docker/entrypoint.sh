#!/usr/bin/env bash
# Start Xvfb + openbox (mirrors linux-display-manager.ts), then exec user command.
set -euo pipefail

if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb "${DISPLAY:-:99}" -screen 0 1024x768x24 &
    sleep 0.5
fi

if ! pgrep -x openbox > /dev/null 2>&1; then
    DISPLAY="${DISPLAY:-:99}" openbox &
    sleep 0.5
fi

exec "$@"
