#!/bin/sh
# Assemble build/Aeris.app from the SwiftPM binary. Usage: scripts/bundle.sh [debug]
set -eu
cd "$(dirname "$0")/.."

CONFIG=release
[ "${1:-}" = "debug" ] && CONFIG=debug

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/AerisEditor"

APP=build/Aeris.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AerisEditor"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "$(pwd)/$APP"
