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
codesign --force --sign - "$APP"
echo "$APP"
