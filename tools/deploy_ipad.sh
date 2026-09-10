#!/usr/bin/env bash
#
# Export SpaceTrader to iOS, patch the generated Xcode project, build it
# signed and install it on a connected iPad.
#
# Godot regenerates space-trader.xcodeproj on every export and drops the
# linker flags that pull main() out of libgodot.a, so the patch step has to
# run after every export -- that is the whole reason this script exists.
#
# Usage: tools/deploy_ipad.sh [--no-export] [--no-launch]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_DIR="$PROJECT_DIR/ipad"
XCODEPROJ="$EXPORT_DIR/space-trader.xcodeproj"
PBXPROJ="$XCODEPROJ/project.pbxproj"
DERIVED_DATA="$EXPORT_DIR/build-dd"
APP="$DERIVED_DATA/Build/Products/Debug-iphoneos/space-trader.app"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PRESET="${PRESET:-iOS}"
BUNDLE_ID="${BUNDLE_ID:-net.testandwin.space-trader}"
# Must match the OU of the signing certificate, not the CN parenthetical.
TEAM_ID="${TEAM_ID:-L2TVTF8WU6}"

DO_EXPORT=1
DO_LAUNCH=1
for arg in "$@"; do
	case "$arg" in
		--no-export) DO_EXPORT=0 ;;
		--no-launch) DO_LAUNCH=0 ;;
		*) echo "unknown option: $arg" >&2; exit 2 ;;
	esac
done

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31merror: %s\033[0m\n' "$1" >&2; exit 1; }

# --- device ---------------------------------------------------------------
step "Locating iPad"
DEVICE_JSON="$(mktemp -t devicectl)"
xcrun devicectl list devices --json-output "$DEVICE_JSON" >/dev/null 2>&1 \
	|| fail "devicectl could not list devices"

read -r UDID DEVICE_NAME < <(python3 - "$DEVICE_JSON" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    props = d["deviceProperties"]
    hw = d["hardwareProperties"]
    if d["connectionProperties"]["tunnelState"] == "unavailable":
        continue
    if hw["platform"] != "iOS":
        continue
    print(hw["udid"], props["name"])
    break
else:
    sys.exit("no connected iOS device found")
PY
) || fail "no connected iOS device found -- plug in the iPad, unlock it and trust this Mac"
echo "    $DEVICE_NAME ($UDID)"

# --- export ---------------------------------------------------------------
if [[ $DO_EXPORT -eq 1 ]]; then
	step "Exporting from Godot"
	[[ -x "$GODOT" ]] || fail "Godot not found at $GODOT (override with GODOT=...)"
	"$GODOT" --headless --path "$PROJECT_DIR" \
		--export-debug "$PRESET" "$XCODEPROJ" \
		|| fail "Godot export failed"
else
	step "Skipping export (--no-export)"
fi

[[ -f "$PBXPROJ" ]] || fail "missing $PBXPROJ"

# --- patch ----------------------------------------------------------------
# Without -ObjC -all_load the linker never pulls the object file holding
# main() out of the static libgodot.a, producing "Undefined symbol: _main".
step "Patching OTHER_LDFLAGS (-ObjC -all_load)"
if grep -q -- "-all_load" "$PBXPROJ"; then
	echo "    already patched"
else
	perl -pi -e 's/(OTHER_LDFLAGS = "\$\(LD_CLASSIC_\$\(XCODE_VERSION_ACTUAL\)\))(\s*)";/$1 -ObjC -all_load ";/g' "$PBXPROJ"
	grep -q -- "-all_load" "$PBXPROJ" || fail "could not patch OTHER_LDFLAGS -- check the pbxproj format"
	echo "    patched $(grep -c -- '-all_load' "$PBXPROJ") configuration(s)"
fi

# --- build ----------------------------------------------------------------
# Device only: the template's "ios-arm64_x86_64-simulator" slice is x86_64
# only, so an arm64 simulator build can never resolve _main.
step "Building for device"
xcodebuild -project "$XCODEPROJ" -scheme space-trader -configuration Debug \
	-destination "id=$UDID" -derivedDataPath "$DERIVED_DATA" \
	DEVELOPMENT_TEAM="$TEAM_ID" build 2>&1 \
	| grep -vE "ld: warning: ignoring file" \
	| grep -E "error:|warning: .*(deprecat|profile)|BUILD (SUCCEEDED|FAILED)" || true

[[ -d "$APP" ]] || fail "build produced no app bundle at $APP"

# --- install --------------------------------------------------------------
step "Installing on $DEVICE_NAME"
xcrun devicectl device install app --device "$UDID" "$APP" \
	|| fail "install failed"

# --- launch ---------------------------------------------------------------
if [[ $DO_LAUNCH -eq 1 ]]; then
	step "Launching"
	if ! xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" 2>&1 | tail -3; then
		cat <<-EOF

		The app is installed but refused to launch. With a free Apple
		developer account this is expected on the first install: trust the
		certificate on the iPad under
		  Settings > General > VPN & Device Management > Michael Schlottmann
		then start the app from the home screen.
		EOF
	fi
fi

step "Done"
