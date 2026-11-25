#!/bin/bash
# Builds "Claude Switcher.app" and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Claude Switcher.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"
swiftc -O -target "$(uname -m)-apple-macosx15.0" -o "$APP/Contents/MacOS/ClaudeSwitcher" main.swift badges.swift

# App icon: render icon.swift once and scale it to all sizes macOS expects.
mkdir -p "$APP/Contents/Resources" build/AppIcon.iconset
swift icon.swift build/icon.png
for n in 16 32 128 256 512; do
  sips -z $n $n build/icon.png --out "build/AppIcon.iconset/icon_${n}x${n}.png" >/dev/null
  sips -z $((n*2)) $((n*2)) build/icon.png --out "build/AppIcon.iconset/icon_${n}x${n}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Claude Switcher</string>
  <key>CFBundleIdentifier</key><string>local.claude-switcher</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>ClaudeSwitcher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Claude Switcher.app"
cp -R "$APP" "$HOME/Applications/"
echo "Installiert: ~/Applications/Claude Switcher.app"
