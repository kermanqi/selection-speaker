#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="划词朗读器"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VERSION="${1:-${VERSION:-1.0}}"

if [[ $# -gt 1 ]]; then
    print -u2 "usage: $0 [version]"
    exit 2
fi

cd "$ROOT_DIR"

typeset -a binaries
for arch in arm64 x86_64; do
    swift build \
        -c release \
        --arch "$arch" \
        --build-path "$ROOT_DIR/.build/$arch" \
        --product SelectionSpeaker
    binaries+=("$ROOT_DIR/.build/$arch/release/SelectionSpeaker")
done

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
lipo -create "${binaries[@]}" -output "$MACOS_DIR/$APP_NAME"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>local.selection-speaker</string>
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
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>用于读取当前选中的文本并调用系统语音朗读，可选发送到翻译服务显示中文翻译。</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null
echo "$APP_DIR"
