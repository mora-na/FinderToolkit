#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/FinderToolkit/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
DMG_PATH="$ROOT_DIR/dist/FinderToolkit-$VERSION.dmg"

TMP_DIR=""
DMG_CREATED=0
PACKAGE_COMPLETE=0

trash_if_exists() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        /usr/bin/trash "$path"
    fi
}

cleanup() {
    local exit_status=$?
    trap - EXIT

    if [[ "$PACKAGE_COMPLETE" != 1 && "$DMG_CREATED" == 1 ]]; then
        trash_if_exists "$DMG_PATH"
    fi

    if [[ -n "$TMP_DIR" && "$TMP_DIR" == /private/tmp/FinderToolkit-release.* ]]; then
        trash_if_exists "$TMP_DIR"
    fi

    if (( exit_status != 0 )) && [[ -n "$TMP_DIR" || "$DMG_CREATED" == 1 ]]; then
        echo "Release packaging failed; temporary outputs were moved to Trash." >&2
    fi

    exit "$exit_status"
}

trap cleanup EXIT

if [[ -e "$DMG_PATH" ]]; then
    echo "Release output already exists. Move it to Trash before rebuilding:" >&2
    echo "  $DMG_PATH" >&2
    exit 1
fi

# Remove only artifacts created by older versions of this release script.
trash_if_exists "$ROOT_DIR/build"
trash_if_exists "$ROOT_DIR/dist/FinderToolkit-$VERSION"
trash_if_exists "$ROOT_DIR/dist/FinderToolkit-latest.dmg"

TMP_DIR="$(mktemp -d /private/tmp/FinderToolkit-release.XXXXXX)"
BUILD_DIR="$TMP_DIR/Build"
APP_PATH="$BUILD_DIR/Build/Products/Release/FinderToolkit.app"
STAGE_DIR="$TMP_DIR/Stage"

mkdir -p "$BUILD_DIR" "$STAGE_DIR" "$ROOT_DIR/dist"

xcodebuild \
    -project "$ROOT_DIR/FinderToolkit.xcodeproj" \
    -scheme FinderToolkit \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    REGISTER_WITH_LAUNCH_SERVICES=NO \
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

DMG_CREATED=1
hdiutil create \
    -volname FinderToolkit \
    -srcfolder "$STAGE_DIR" \
    -format UDZO \
    "$DMG_PATH"

codesign --force --sign - --timestamp=none "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
hdiutil verify "$DMG_PATH"
PACKAGE_COMPLETE=1

echo "FinderToolkit $VERSION ($BUILD_NUMBER)"
shasum -a 256 "$DMG_PATH"
