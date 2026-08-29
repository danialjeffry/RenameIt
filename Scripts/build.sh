#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="RenameIt"
DEST="${APP_NAME}.app"
CONTENTS="${DEST}/Contents"
MACOS="${CONTENTS}/MacOS"

rm -rf "$DEST"
mkdir -p "$MACOS"

echo "Compiling..."
swiftc -O -target arm64-apple-macosx14.0 \
  -parse-as-library \
  Sources/${APP_NAME}App.swift Sources/AppDelegate.swift Sources/RenameModel.swift Sources/RenameView.swift \
  -o "${MACOS}/${APP_NAME}"

cat > "${CONTENTS}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>RenameIt</string>
    <key>CFBundleDisplayName</key>
    <string>RenameIt</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.RenameIt</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>RenameIt</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$DEST" 2>/dev/null || true

echo "Built ${DEST}"
