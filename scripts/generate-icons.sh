#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ICON="$ROOT_DIR/public/clawtributor-square-1200x1200.jpg"
ASSETS_DIR="$ROOT_DIR/assets"
WORK_DIR="$(mktemp -d)"
ICONSET_DIR="$WORK_DIR/icon.iconset"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$ASSETS_DIR"
mkdir -p "$ICONSET_DIR"

sips -s format png -z 1024 1024 "$SOURCE_ICON" --out "$ASSETS_DIR/icon.png" >/dev/null
sips -s format png -z 16 16 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$ASSETS_DIR/icon.icns"

sips -s format png -z 256 256 "$SOURCE_ICON" --out "$WORK_DIR/icon-256.png" >/dev/null
node - "$WORK_DIR/icon-256.png" "$ASSETS_DIR/icon.ico" <<'NODE'
const fs = require("fs");
const inputPath = process.argv[2];
const outputPath = process.argv[3];
const png = fs.readFileSync(inputPath);
const header = Buffer.alloc(6);
header.writeUInt16LE(0, 0);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(1, 4);
const directory = Buffer.alloc(16);
directory.writeUInt8(0, 0);
directory.writeUInt8(0, 1);
directory.writeUInt8(0, 2);
directory.writeUInt8(0, 3);
directory.writeUInt16LE(1, 4);
directory.writeUInt16LE(32, 6);
directory.writeUInt32LE(png.length, 8);
directory.writeUInt32LE(22, 12);
fs.writeFileSync(outputPath, Buffer.concat([header, directory, png]));
NODE

echo "$ASSETS_DIR/icon.icns"
echo "$ASSETS_DIR/icon.ico"
