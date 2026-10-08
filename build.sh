#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="$PROJECT_DIR/MoveMouse.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 جاري بناء تطبيق MoveMouse لنظام macOS..."

# Clean old bundle
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Icon
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Compile Swift sources with optimizations
swiftc -O \
    -target arm64-apple-macos11.0 \
    "$PROJECT_DIR/src/SleepManager.swift" \
    "$PROJECT_DIR/src/MouseMover.swift" \
    "$PROJECT_DIR/src/AppDelegate.swift" \
    "$PROJECT_DIR/src/main.swift" \
    -o "$MACOS_DIR/MoveMouse"

# Create Info.plist
cat << 'PLIST_EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MoveMouse</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.alhamou.MoveMouse</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MoveMouse</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MoveMouse needs accessibility permission to simulate mouse movements and keep your RDP session active.</string>
</dict>
</plist>
PLIST_EOF

# Ad-hoc sign the bundle
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ تم بناء MoveMouse.app بنجاح في: $APP_BUNDLE"
