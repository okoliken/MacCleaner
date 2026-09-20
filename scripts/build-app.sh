#!/bin/zsh
# Builds build/MacCleaner.app from the SwiftPM package.
# Usage: scripts/build-app.sh            → build only
#        scripts/build-app.sh --install  → build, then copy into /Applications
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MacCleaner"
BUNDLE_ID="com.okoliken.maccleaner"
VERSION="0.1.0"
APP="build/$APP_NAME.app"

echo "▸ Compiling (release)…"
swift build -c release --product MacCleanerApp
BINARY="$(swift build -c release --show-bin-path)/MacCleanerApp"

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"

echo "▸ Drawing icon…"
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
swift scripts/make-icon.swift "$ICONSET" > /dev/null
iconutil --convert icns "$ICONSET" --output "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Info.plist is the app's ID card. The important keys:
#   CFBundleExecutable  – which file in Contents/MacOS to launch
#   CFBundleIdentifier  – unique ID; macOS keys permissions and settings off it
#   LSUIElement         – menu-bar only: no Dock icon, no app menu
#   NS…UsageDescription – text shown when macOS asks "allow access to Desktop?"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>          <string>Mac Cleaner</string>
    <key>CFBundleExecutable</key>           <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>           <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleShortVersionString</key>   <string>$VERSION</string>
    <key>CFBundleVersion</key>              <string>1</string>
    <key>LSMinimumSystemVersion</key>       <string>14.0</string>
    <key>LSUIElement</key>                  <true/>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Mac Cleaner looks for old screenshots and screen recordings on your Desktop.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Mac Cleaner looks for screenshots saved to your Documents folder.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Mac Cleaner looks for leftover files in your Downloads folder.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature ("-"): no Apple account needed, and Apple Silicon refuses to run
# unsigned code. Swap "-" for a "Developer ID Application: …" identity to distribute.
echo "▸ Signing…"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "✓ Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "✓ Installed to /Applications/$APP_NAME.app"
fi
