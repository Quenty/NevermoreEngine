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

# Re-detect network interfaces so Wine sees the runtime network, not the
# stale build-time config baked in by wineboot -i during docker build.
wineboot -u > /dev/null 2>&1 || true

exec "$@"
