#!/bin/bash
echo "🛑 Stopping MoveMouse..."
pkill -x MoveMouse 2>/dev/null && echo "✅ MoveMouse stopped." || echo "ℹ️ MoveMouse was not running."
