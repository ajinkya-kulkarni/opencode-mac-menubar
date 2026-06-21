#!/usr/bin/env bash
set -euo pipefail

APP_NAME="OpenCodeGoLite"
BUNDLE_NAME="${APP_NAME}.app"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/$BUNDLE_NAME"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Please install Xcode Command Line Tools first: xcode-select --install" >&2
  exit 1
fi

mkdir -p "$MACOS_DIR" "$RES_DIR"

SWIFT_FILES=("$ROOT_DIR"/Sources/OpenCodeGoLite/*.swift)

xcrun swiftc -Onone \
  -framework AppKit \
  -framework Foundation \
  "${SWIFT_FILES[@]}" \
  -o "$MACOS_DIR/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.ajinkya.OpenCodeGoLite</string>
  <key>CFBundleName</key>
  <string>OpenCodeGoLite</string>
  <key>CFBundleDisplayName</key>
  <string>OpenCode Go Lite</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "Built: $APP_DIR"
echo "Run:   open '$APP_DIR'"
