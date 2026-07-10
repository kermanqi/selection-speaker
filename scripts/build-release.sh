#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="划词朗读器"
VERSION="${1:-${VERSION:-}}"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/build/releases"
DMG_ROOT="$ROOT_DIR/build/dmg-root"
ZIP_PATH="$RELEASE_DIR/SelectionSpeaker-$VERSION-macos-universal.zip"
DMG_PATH="$RELEASE_DIR/SelectionSpeaker-$VERSION-macos-universal.dmg"
CHECKSUM_PATH="$RELEASE_DIR/SelectionSpeaker-$VERSION-checksums.txt"

if [[ -z "$VERSION" || $# -gt 1 ]]; then
    print -u2 "usage: $0 <version>"
    exit 2
fi

cd "$ROOT_DIR"
rm -rf "$RELEASE_DIR" "$DMG_ROOT"
mkdir -p "$RELEASE_DIR" "$DMG_ROOT"

VERSION="$VERSION" "$ROOT_DIR/scripts/build-app.sh" "$VERSION"

ditto -c -k --norsrc --keepParent \
    "$APP_DIR" \
    "$ZIP_PATH"

cp -R "$APP_DIR" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
/usr/bin/hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

cd "$RELEASE_DIR"
shasum -a 256 "$(basename "$DMG_PATH")" "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"

rm -rf "$DMG_ROOT"
print "$RELEASE_DIR"
