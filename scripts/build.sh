#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo 'Invalid build number'; exit 2; }
swift build --configuration release --arch arm64
BIN_DIR="$(swift build --configuration release --arch arm64 --show-bin-path)"
APP="$ROOT/dist/WorkFee.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/.build/AppIcon.iconset"
cp "$BIN_DIR/WorkFee" "$APP/Contents/MacOS/WorkFee"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
swift "$ROOT/scripts/make-icon.swift" "$ROOT/.build/icon-1024.png"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$ROOT/.build/icon-1024.png" --out "$ROOT/.build/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$ROOT/.build/icon-1024.png" --out "$ROOT/.build/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil --convert icns "$ROOT/.build/AppIcon.iconset" --output "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
file "$APP/Contents/MacOS/WorkFee"
test "$(lipo -archs "$APP/Contents/MacOS/WorkFee")" = 'arm64'
echo "$APP"
