#!/usr/bin/env bash

# Package the already verified native host build as a distributable DMG.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGURATION="${1:-Release}"
VERSION="${VERSION:-0.2.0}"
TARGET_ARCH="$(uname -m)"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$PROJECT_DIR/.build/HostDerivedData/Build/Products/$CONFIGURATION/Tilde.app"
DMG_PATH="$DIST_DIR/Tilde_${VERSION}_${TARGET_ARCH}.dmg"
STAGING_DIR="$DIST_DIR/dmg-root"

cd "$PROJECT_DIR"
"$SCRIPT_DIR/verify-host.sh" "$CONFIGURATION"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: app bundle not found at $APP_PATH" >&2
    exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Tilde" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"
echo "Created $DMG_PATH"
