#!/bin/bash
# Redeploy using the installed app's exact signing certificate and entitlements.
# Usage: bash Scripts/build-and-install.sh [absolute-derived-data-directory]
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"
INSTALL="/Applications/LightsOut.app"
DERIVED="$PROJECT_DIR/build_release"
if [ "$#" -gt 0 ]; then DERIVED="$1"; fi
case "$DERIVED" in /*) ;; *) echo "Derived data path must be absolute." >&2; exit 1;; esac
[ -d "$INSTALL" ] || { echo "An installed LightsOut.app is required to reuse its signature." >&2; exit 1; }

TMP="$(mktemp -d /tmp/lightsout-deploy.XXXXXX)"
STAGE=""
BACKUP=""
MOVED=0
cleanup() {
    result=$?
    trap - EXIT
    if [ "$result" -ne 0 ] && [ "$MOVED" -eq 1 ]; then
        if [ -e "$INSTALL" ]; then
            mv "$INSTALL" "$INSTALL.failed.$(date +%Y%m%d-%H%M%S).$$"
        fi
        mv "$BACKUP" "$INSTALL"
        open "$INSTALL" || true
        echo "Restored previous app after deployment failure." >&2
    fi
    if [ -n "$STAGE" ]; then rm -rf "$STAGE"; fi
    rm -rf "$TMP"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

codesign --verify --deep --strict "$INSTALL"
codesign --display --extract-certificates="$TMP/installed-cert-" "$INSTALL" 2>/dev/null
IDENTITY="$(shasum -a 1 "$TMP/installed-cert-0" | awk '{ print toupper($1) }')"
security find-identity -v -p codesigning > "$TMP/identities"
awk -v expected="$IDENTITY" '$2 == expected { found=1 } END { exit !found }' "$TMP/identities" ||
    { echo "The installed signing certificate has no valid matching private key." >&2; exit 1; }
codesign -d --entitlements :- "$INSTALL" > "$TMP/entitlements.plist" 2>/dev/null
codesign -d -r- "$INSTALL" > "$TMP/requirements" 2>/dev/null
REQUIREMENT="$(sed -n 's/^designated => //p' "$TMP/requirements")"
[ -n "$REQUIREMENT" ]
echo "Reusing certificate SHA-1: $IDENTITY"

bash Scripts/test-safety.sh
env -u CC -u CXX xcodebuild -project LightsOut.xcodeproj -scheme LightsOut \
    -configuration Release -derivedDataPath "$DERIVED" \
    build CODE_SIGNING_ALLOWED=NO > "$TMP/build.log" 2>&1 ||
    { tail -n 60 "$TMP/build.log"; exit 1; }
APP="$DERIVED/Build/Products/Release/LightsOut.app"
# Never silently reuse obsolete entitlements if a later source change needs different ones.
python3 - "$TMP/entitlements.plist" "$PROJECT_DIR/LightsOut/LightsOut.entitlements" <<'PY'
import plistlib, sys
from pathlib import Path
installed = plistlib.loads(Path(sys.argv[1]).read_bytes())
source = Path(sys.argv[2]).read_text().replace("$(PRODUCT_BUNDLE_IDENTIFIER)", "Steelworks.LightsOut")
if installed != plistlib.loads(source.encode()):
    raise SystemExit("Source entitlements differ from installed app; reconcile before same-sign deployment.")
PY

SPK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for component in "$SPK/XPCServices/Installer.xpc" "$SPK/XPCServices/Downloader.xpc" \
                 "$SPK/Autoupdate" "$SPK/Updater.app" "$APP/Contents/Frameworks/Sparkle.framework"; do
    [ -e "$component" ]
    codesign --force --options runtime --sign "$IDENTITY" "$component"
done
codesign --force --options runtime --entitlements "$TMP/entitlements.plist" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict -R "=$REQUIREMENT" "$APP"
codesign --display --extract-certificates="$TMP/new-cert-" "$APP" 2>/dev/null
cmp "$TMP/installed-cert-0" "$TMP/new-cert-0"
codesign -d --entitlements :- "$APP" > "$TMP/new-entitlements.plist" 2>/dev/null
python3 - "$TMP/entitlements.plist" "$TMP/new-entitlements.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as a, open(sys.argv[2], "rb") as b:
    assert plistlib.load(a) == plistlib.load(b), "Entitlements changed during signing"
PY

STAGE="$(mktemp -d /Applications/.lightsout-stage.XXXXXX)"
ditto "$APP" "$STAGE/LightsOut.app"
codesign --verify --deep --strict -R "=$REQUIREMENT" "$STAGE/LightsOut.app"

# Migrate intent before an older app clears its observed state while quitting.
# Existing preferences (including an explicit all-on configuration) always win.
python3 - <<'MIGRATE'
import json, os
from pathlib import Path
root = Path.home() / "Library/Containers/Steelworks.LightsOut/Data/Library/Application Support/LightsOut"
destination = root / "display-preferences.json"
journal = root / "display-state.json"
if not destination.exists() and journal.exists():
    state = json.loads(journal.read_text())
    visible = {d["uuid"] for d in state if d.get("uuid") and d.get("state") == "active"}
    entries = []
    for display in state:
        uuid = display.get("uuid")
        supports = sorted(visible - {uuid})
        if uuid and supports and display.get("state") in ("mirrored", "disconnected"):
            mode = "blackout" if display.get("isBuiltIn") or display["state"] == "mirrored" else "disconnect"
            entries.append({"targetUUID": uuid, "mode": mode, "supportingUUIDs": supports})
    temporary = destination.with_suffix(".migration.tmp")
    temporary.write_text(json.dumps(entries, indent=2))
    os.replace(temporary, destination)
    print(f"Migrated {len(entries)} saved display choices before quitting the old app.")
MIGRATE

# Quit gracefully. Never force-kill a display controller during a configuration.
if pgrep -x LightsOut >/dev/null; then
    osascript <<'APPLESCRIPT'
with timeout of 10 seconds
    tell application id "Steelworks.LightsOut" to quit
end timeout
APPLESCRIPT
fi
for attempt in 1 2 3 4 5; do
    if ! pgrep -x LightsOut >/dev/null; then break; fi
    sleep 1
done
if pgrep -x LightsOut >/dev/null; then
    echo "LightsOut did not quit gracefully; installed app left intact." >&2
    exit 1
fi

BACKUP="$INSTALL.backup.$(date +%Y%m%d-%H%M%S).$$"
mv "$INSTALL" "$BACKUP"
MOVED=1
mv "$STAGE/LightsOut.app" "$INSTALL"
codesign --verify --deep --strict -R "=$REQUIREMENT" "$INSTALL"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$INSTALL"
open "$INSTALL"
for attempt in 1 2 3 4 5; do
    if pgrep -x LightsOut >/dev/null; then break; fi
    sleep 1
done
pgrep -x LightsOut >/dev/null
sleep 2
pgrep -x LightsOut >/dev/null
MOVED=0
echo "Deployed: $INSTALL"
echo "Backup: $BACKUP"
codesign -dvv "$INSTALL" 2>&1 | sed -n '/^Identifier=/p; /^Authority=/p; /^TeamIdentifier=/p'
