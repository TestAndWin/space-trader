#!/usr/bin/env bash
# Stop-Hook: prüft, ob jede data/**/*.tres in resource_registry.gd registriert ist.
# CLAUDE.md: DirAccess kann .tres im exportierten PCK nicht listen -> alle Pfade
# müssen explizit in ResourceRegistry stehen, sonst fehlen sie im Export.
# Bei fehlenden Einträgen: exit 2 -> stderr geht an Claude, das den Eintrag nachträgt.
set -euo pipefail

cd "$(dirname "$0")/../.." || exit 0

# Endlosschleife vermeiden: war dieser Hook schon aktiv, nicht erneut blockieren.
input="$(cat || true)"
if printf '%s' "$input" | grep -q '"stop_hook_active":[[:space:]]*true'; then
  exit 0
fi

registry="scripts/autoloads/resource_registry.gd"
[ -f "$registry" ] || exit 0

missing=""
while IFS= read -r f; do
  res_path="res://$f"
  # Pfad als res:// oder relativ in der Registry suchen
  if ! grep -qF "$res_path" "$registry" && ! grep -qF "\"$f\"" "$registry"; then
    missing="${missing}  ⚠️  $res_path${IFS:0:1}"
  fi
done < <(find data -name '*.tres' 2>/dev/null | sort)

if [ -n "$missing" ]; then
  printf 'Diese .tres-Dateien sind NICHT in %s registriert. Trage ihre res://-Pfade dort in die passende Konstante ein (siehe CLAUDE.md "Adding Game Content"):\n%s\n' "$registry" "$missing" >&2
  exit 2
fi

exit 0
