#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/FinderToolkit/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
BUILD_DIR="$ROOT_DIR/build/Release"
APP_PATH="$BUILD_DIR/Build/Products/Release/FinderToolkit.app"
STAGE_DIR="$ROOT_DIR/dist/FinderToolkit-$VERSION"
DMG_PATH="$ROOT_DIR/dist/FinderToolkit-$VERSION.dmg"
LATEST_DMG_PATH="$ROOT_DIR/dist/FinderToolkit-latest.dmg"

if [[ -e "$BUILD_DIR" || -e "$STAGE_DIR" || -e "$DMG_PATH" || -e "$LATEST_DMG_PATH" ]]; then
    echo "Release output already exists. Move it to Trash before rebuilding:" >&2
    echo "  $BUILD_DIR" >&2
    echo "  $STAGE_DIR" >&2
    echo "  $DMG_PATH" >&2
    echo "  $LATEST_DMG_PATH" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR" "$STAGE_DIR"

xcodebuild \
    -project "$ROOT_DIR/FinderToolkit.xcodeproj" \
    -scheme FinderToolkit \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    DEBUG_INFORMATION_FORMAT=none \
    GCC_GENERATE_DEBUGGING_SYMBOLS=NO \
    SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
    SWIFT_REFLECTION_METADATA_LEVEL=none \
    OTHER_SWIFT_FLAGS="-debug-prefix-map $ROOT_DIR=. -prefix-serialized-debugging-options" \
    build

EXTENSION_PATH="$APP_PATH/Contents/PlugIns/FinderToolkitExtension.appex"

codesign --force --sign - --timestamp=none \
    --entitlements "$ROOT_DIR/FinderToolkitExtension/FinderToolkitExtension.entitlements" \
    "$EXTENSION_PATH"
codesign --force --sign - --timestamp=none \
    --entitlements "$ROOT_DIR/FinderToolkit/FinderToolkit.entitlements" \
    "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

USER_NAME="$(id -un)"
USER_HOME="$(dscacheutil -q user -a name "$USER_NAME" | awk '/^dir: / { print $2; exit }')"
for private_value in "$USER_NAME" "$USER_HOME"; do
    if [[ -n "$private_value" ]] && rg -a -l -F "$private_value" "$APP_PATH" >/dev/null; then
        echo "Privacy scan failed: local account data is present in the app bundle." >&2
        exit 1
    fi
done

if rg -a -l -e '[A-Za-z][A-Za-z0-9._%+-]*@[A-Za-z][A-Za-z0-9.-]*\.[A-Za-z]{2,}' "$APP_PATH" >/dev/null; then
    echo "Privacy scan failed: an email address is present in the app bundle." >&2
    exit 1
fi

ditto "$APP_PATH" "$STAGE_DIR/FinderToolkit.app"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
    -volname FinderToolkit \
    -srcfolder "$STAGE_DIR" \
    -format UDZO \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"

codesign --force --sign - --timestamp=none "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

ditto "$DMG_PATH" "$LATEST_DMG_PATH"
codesign --verify --verbose=2 "$LATEST_DMG_PATH"

echo "FinderToolkit $VERSION ($BUILD_NUMBER)"
shasum -a 256 "$DMG_PATH"
shasum -a 256 "$LATEST_DMG_PATH"
