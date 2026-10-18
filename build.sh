#!/bin/zsh
set -eu
setopt pipefail
cd -- "${0:A:h}"
PROJECT_ROOT="$PWD"
VERSION="$(< VERSION)"
METER_MIN_MACOS_VERSION="$(< MACOS_MIN_VERSION)"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { print -u2 'VERSIONの形式が不正です'; exit 1; }
for TOOL in swiftc sips iconutil codesign; do
    command -v "$TOOL" >/dev/null || { print -u2 "必要なコマンドがありません: $TOOL"; exit 1; }
done
mkdir -p build
cd build
mkdir -p 'Codex Meter.app/Contents/MacOS'
mkdir -p 'Codex Meter.app/Contents/Resources' AppIcon.iconset
for ICON_SIZE in 16 32 128 256 512; do
    sips -z "$ICON_SIZE" "$ICON_SIZE" "$PROJECT_ROOT/assets/AppIcon.png" --out "AppIcon.iconset/icon_${ICON_SIZE}x${ICON_SIZE}.png" >/dev/null
    ICON_RETINA=$((ICON_SIZE * 2))
    sips -z "$ICON_RETINA" "$ICON_RETINA" "$PROJECT_ROOT/assets/AppIcon.png" --out "AppIcon.iconset/icon_${ICON_SIZE}x${ICON_SIZE}@2x.png" >/dev/null
done
iconutil -c icns AppIcon.iconset -o 'Codex Meter.app/Contents/Resources/AppIcon.icns'
METER_CACHE="${TMPDIR:-/tmp}/codex-meter-module-cache"
CLANG_MODULE_CACHE_PATH="$METER_CACHE" swiftc -swift-version 5 -module-cache-path "$METER_CACHE" -target "arm64-apple-macos$METER_MIN_MACOS_VERSION" -O "$PROJECT_ROOT"/src/*.swift "$PROJECT_ROOT"/src/Views/*.swift -o 'Codex Meter.app/Contents/MacOS/CodexMeter' -framework Cocoa -framework UserNotifications
cat > 'Codex Meter.app/Contents/Info.plist' <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexMeter</string>
<key>CFBundleIdentifier</key><string>local.codex.meter</string>
<key>CFBundleName</key><string>Codex Meter</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>6</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>$METER_MIN_MACOS_VERSION</string>
</dict></plist>
PLIST
plutil -lint 'Codex Meter.app/Contents/Info.plist'
codesign --force --sign - 'Codex Meter.app'
codesign --verify --strict 'Codex Meter.app'
echo "作成完了: build/Codex Meter.app ($VERSION / Apple Silicon、アドホック署名)"
