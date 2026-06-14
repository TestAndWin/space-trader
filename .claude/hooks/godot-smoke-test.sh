#!/usr/bin/env bash
# Stop-Hook: lädt das Projekt headless und fängt Parse-/Load-Fehler ab,
# bevor man in den Godot-Editor wechselt. Bei Fehlern: exit 2 -> Meldung an Claude.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 0

# Endlosschleife vermeiden.
input="$(cat || true)"
if printf '%s' "$input" | grep -q '"stop_hook_active":[[:space:]]*true'; then
  exit 0
fi

# Godot-Binary finden (macOS-App oder PATH); sonst still überspringen,
# damit der Hook auf anderen Maschinen nicht bricht.
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$GODOT" ]; then
  GODOT="$(command -v godot || command -v godot4 || true)"
fi
[ -n "$GODOT" ] && [ -x "$GODOT" ] || exit 0

out="$("$GODOT" --headless --path "$(pwd)" --quit-after 5 2>&1 || true)"

# Godot meldet Skript-/Parse-Fehler über diese Marker.
if printf '%s' "$out" | grep -qE 'SCRIPT ERROR|Parse Error|Parser Error|ERROR: .*\.gd'; then
  errs="$(printf '%s' "$out" | grep -E 'SCRIPT ERROR|Parse Error|Parser Error|ERROR: .*\.gd' | head -20)"
  printf 'Godot Headless-Load meldet Fehler — bitte beheben:\n%s\n' "$errs" >&2
  exit 2
fi

exit 0
