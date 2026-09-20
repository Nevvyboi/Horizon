#!/usr/bin/env bash
# Build Horizon and assemble it into a macOS .app bundle.
#
# Swift Package Manager produces a bare executable, so we wrap it here. The app
# is an agent (LSUIElement), which is what makes it live only in the menu bar
# with no Dock icon and no window in the app switcher.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Horizon"
BUNDLE_ID="life.floati.horizon"
VERSION="0.2.0"
OUT="build/${APP_NAME}.app"

echo "Building release binary..."
swift build -c release

BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"

echo "Assembling ${OUT}..."
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/${APP_NAME}"

if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$OUT/Contents/Resources/AppIcon.icns"
fi
# Bundle image assets (the zebra mark) so Bundle.main can find them.
for png in Resources/*.png; do
  [ -f "$png" ] && cp "$png" "$OUT/Contents/Resources/"
done

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <!-- Menu bar only: no Dock icon, no app switcher entry. -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS is happy to run it locally.
codesign --force --deep --sign - "$OUT" 2>/dev/null || true

echo "Built ${OUT}"
