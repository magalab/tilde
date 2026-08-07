#!/usr/bin/env bash

# Generate the macOS AppIcon.icns resource from the project logo source.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_LOGO="${SOURCE_LOGO:-$PROJECT_DIR/Assets/TildeAppIcon.png}"
ICON_SET_DIR="${ICON_SET_DIR:-$PROJECT_DIR/AppIcon.iconset}"
OUTPUT_ICNS="${OUTPUT_ICNS:-$PROJECT_DIR/AppIcon.icns}"

if [[ ! -f "$SOURCE_LOGO" ]]; then
    echo "Error: logo source not found at $SOURCE_LOGO" >&2
    exit 1
fi

mkdir -p "$ICON_SET_DIR"
rm -f "$ICON_SET_DIR"/*.png

echo "Creating macOS icon from $SOURCE_LOGO"
sips -z 16 16 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SOURCE_LOGO" --out "$ICON_SET_DIR/icon_512x512@2x.png" >/dev/null

validate_rgba_png() {
    local path="$1"
    local metadata
    metadata="$(sips -g format -g hasAlpha "$path")"
    if [[ "$metadata" != *"format: png"* || "$metadata" != *"hasAlpha: yes"* ]]; then
        echo "Error: expected an RGBA PNG: $path" >&2
        exit 1
    fi
}

validate_rgba_png "$SOURCE_LOGO"

for icon in "$ICON_SET_DIR"/*.png; do
    validate_rgba_png "$icon"
done

iconutil -c icns "$ICON_SET_DIR" -o "$OUTPUT_ICNS"
echo "Created $OUTPUT_ICNS"
