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

# iconutil requires RGBA PNGs. The generated source can be opaque RGB, so
# redraw each size into an explicit alpha bitmap before assembling the ICNS.
swift -e 'import AppKit; import Foundation; for path in CommandLine.arguments.dropFirst() { let url = URL(fileURLWithPath: path); let image = NSImage(contentsOf: url)!; let size = image.size; let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: NSColorSpaceName.deviceRGB, bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0)!; NSGraphicsContext.saveGraphicsState(); let context = NSGraphicsContext(bitmapImageRep: rep)!; NSGraphicsContext.current = context; image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1); context.flushGraphics(); NSGraphicsContext.restoreGraphicsState(); let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!; try! data.write(to: url) }' "$ICON_SET_DIR"/*.png

iconutil -c icns "$ICON_SET_DIR" -o "$OUTPUT_ICNS"
echo "Created $OUTPUT_ICNS"
