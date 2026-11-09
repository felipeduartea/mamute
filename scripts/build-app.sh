#!/bin/bash
# Builds build/Mamute.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Mamute.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Mamute "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
# App icon: every size macOS wants, generated from the 1024px Resources/AppIcon.png.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET" "$APP/Contents/Resources"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
# A stable certificate keeps macOS's audio permission across rebuilds; ad-hoc signing is new every build.
IDENTITY=$(security find-identity -v -p codesigning | grep -oE '"(Developer ID Application|Apple Development)[^"]*"' | head -1 | tr -d '"' || true)
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Signed with: ${IDENTITY:-ad-hoc (macOS will ask for audio permission again after each rebuild)}"
echo "$APP"
