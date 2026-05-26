#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_APP_DIR="$ROOT_DIR/apps/macos-swift"
VERSION="$(node -e "process.stdout.write(require('$ROOT_DIR/package.json').version)")"
APP_NAME="Clawtributor Status Native"
PRODUCT_NAME="ClawtributorStatus"
BUILD_DIR="$SWIFT_APP_DIR/.build/release"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/Clawtributor Status Native-$VERSION-mac-arm64.zip"

cd "$SWIFT_APP_DIR"
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/SharedContract"

cp "$BUILD_DIR/$PRODUCT_NAME" "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
cp -R "$ROOT_DIR/packages/github-contract/queries" "$APP_BUNDLE/Contents/Resources/SharedContract/queries"
cp -R "$ROOT_DIR/packages/github-contract/schema" "$APP_BUNDLE/Contents/Resources/SharedContract/schema"
cp -R "$ROOT_DIR/packages/github-contract/fixtures" "$APP_BUNDLE/Contents/Resources/SharedContract/fixtures"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.romneyda.clawtributorstatus.native</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Dallin Romney. MIT License.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "$ZIP_PATH"
