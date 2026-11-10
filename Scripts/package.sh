#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
swift build -c release --arch arm64
BIN_DIR=$(swift build -c release --arch arm64 --show-bin-path)
APP="$PWD/dist/NotchLingo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NotchLingo" "$APP/Contents/MacOS/NotchLingo"
for bundle in "$BIN_DIR"/*.bundle; do
    [ -d "$bundle" ] || continue
    ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist" >/dev/null 2>&1 || cp Scripts/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
swift Scripts/Icon.swift "$PWD/dist/AppIcon.iconset"
iconutil -c icns "$PWD/dist/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/NotchLingo-macOS-arm64.zip"
mkdir -p dist/dmg-stage
ditto "$APP" dist/dmg-stage/NotchLingo.app
ln -sfn /Applications dist/dmg-stage/Applications
hdiutil create -volname NotchLingo -srcfolder dist/dmg-stage -ov -format UDZO dist/NotchLingo-macOS-arm64.dmg
shasum -a 256 dist/NotchLingo-macOS-arm64.zip dist/NotchLingo-macOS-arm64.dmg > dist/SHA256SUMS.txt
printf 'Packaged %s\n' "$APP"
