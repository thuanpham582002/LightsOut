#!/bin/bash
# Build LightsOut (Release), re-sign with your Apple Development identity,
# and install it into /Applications, replacing any existing copy.
#
# Usage:
#   Scripts/build-and-install.sh
#
# Override the signing identity with the IDENTITY env var, e.g.:
#   IDENTITY="Apple Development: you@example.com (TEAMID)" Scripts/build-and-install.sh
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"

BUNDLE_ID="Steelworks.LightsOut"
DERIVED="$PROJECT_DIR/build_release"
APP="$DERIVED/Build/Products/Release/LightsOut.app"
INSTALL_PATH="/Applications/LightsOut.app"

# --- pick signing identity ---------------------------------------------------
if [ -z "${IDENTITY:-}" ]; then
    IDENTITY=$(security find-identity -v -p codesigning \
        | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)"/\1/')
fi
if [ -z "$IDENTITY" ]; then
    echo "Error: no Apple Development signing identity found." >&2
    echo "Set one explicitly: IDENTITY='Apple Development: ...' $0" >&2
    exit 1
fi
echo "=== Using identity: $IDENTITY ==="

# --- build -------------------------------------------------------------------
echo "=== Building Release ==="
env -u CC -u CXX xcodebuild \
    -project LightsOut.xcodeproj \
    -scheme LightsOut \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    build CODE_SIGNING_ALLOWED=NO >/dev/null
echo "Build OK: $APP"

# --- resolve entitlements ($(PRODUCT_BUNDLE_IDENTIFIER) -> bundle id) ---------
ENT="$(mktemp -t lightsout-entitlements.XXXXXX).plist"
sed "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g" \
    "$PROJECT_DIR/LightsOut/LightsOut.entitlements" > "$ENT"

# --- sign inside-out ---------------------------------------------------------
SPK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
echo "=== Signing Sparkle (nested) ==="
codesign --force --options runtime --sign "$IDENTITY" "$SPK/XPCServices/Installer.xpc"
codesign --force --options runtime --sign "$IDENTITY" "$SPK/XPCServices/Downloader.xpc"
codesign --force --options runtime --sign "$IDENTITY" "$SPK/Autoupdate" 2>/dev/null || true
codesign --force --options runtime --sign "$IDENTITY" "$SPK/Updater.app"
codesign --force --options runtime --sign "$IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework"

echo "=== Signing app (with entitlements) ==="
codesign --force --options runtime --entitlements "$ENT" --sign "$IDENTITY" "$APP"

echo "=== Verifying ==="
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvvv "$APP" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier="

# --- install -----------------------------------------------------------------
echo "=== Installing to $INSTALL_PATH ==="
osascript -e 'tell application "LightsOut" to quit' 2>/dev/null || true
sleep 1
pkill -x LightsOut 2>/dev/null || true
sleep 1

rm -rf "$INSTALL_PATH.bak"
[ -d "$INSTALL_PATH" ] && mv "$INSTALL_PATH" "$INSTALL_PATH.bak"
ditto "$APP" "$INSTALL_PATH"

/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$INSTALL_PATH"

echo "=== Launching ==="
open "$INSTALL_PATH"
echo "Done. Previous version (if any) backed up to $INSTALL_PATH.bak"
