#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="$PROJECT_DIR/MoveMouse.app"

# If not built yet, build it
if [ ! -d "$APP_BUNDLE" ]; then
    echo "App not found, building..."
    "$PROJECT_DIR/build.sh"
fi

# Stop existing instance if running
pkill -x MoveMouse 2>/dev/null || true
sleep 0.5

# Launch app
echo "🚀 Starting MoveMouse..."
open "$APP_BUNDLE"
echo "✅ MoveMouse is now running in your macOS menu bar (top right)!"
