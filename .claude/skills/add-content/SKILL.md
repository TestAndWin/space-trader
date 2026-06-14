---
name: add-content
description: Neuen Spielinhalt (Card, Planet, Good, Encounter, Upgrade, Ship, Crew, Planet-/Travel-Event, Rival) als .tres anlegen und korrekt in ResourceRegistry verdrahten. Use when adding any new game-content resource to SpaceTrader.
disable-model-invocation: true
---

# Neuen Spielinhalt anlegen

Strukturierter Ablauf, um Spielinhalt hinzuzufügen, ohne den ResourceRegistry-Footgun
(fehlende Registrierung -> Inhalt fehlt im exportierten PCK).

## Ablauf

1. **Resource-Klasse wählen** (in `scripts/resources/`):
   | Inhalt | Klasse | Verzeichnis |
   |--------|--------|-------------|
   | Karte | `CardData` | `data/cards/` |
   | Planet | `PlanetData` | `data/planets/` |
   | Ware | `GoodData` | `data/goods/` |
   | Gegner | `EncounterData` | `data/encounters/` |
   | Schiff-Upgrade | `ShipUpgradeData` | `data/upgrades/` |
   | Schiff | `ShipData` | `data/ships/` |
   | Crew | `CrewData` | `data/crew/` |
   | Planet-Event | `PlanetEventData` | `data/planet_events/` |
   | Travel-Event | `TravelEventData` | `data/travel_events/` |

2. **`.tres` anlegen** — bestehende Datei im selben Verzeichnis als Vorlage lesen,
   `script_class` / `ExtResource` auf die richtige Resource-Klasse setzen.

3. **In `ResourceRegistry` registrieren** (`scripts/autoloads/resource_registry.gd`):
   res://-Pfad in die passende Konstante eintragen
   (`PLANETS`, `GOODS`, `CARDS`, `ENCOUNTERS`, `UPGRADES`, `COMBAT_UPGRADES`,
   `CREW`, `SHIPS`, `PLANET_EVENTS`, `TRAVEL_EVENTS`, `RIVALS`).
   **Pflicht** — DirAccess kann den PCK nicht listen.

4. **Inhalts-spezifische Zusatzschritte**:
   - **Good**: Planet-Type-Pricing in `EconomyManager` ergänzen.
   - **Planet**: Connection-Graph in den verbundenen Planeten beidseitig aktualisieren.
   - **Card**: SaveManager speichert Karten per Resource-Pfad — Pfad muss stabil sein.

5. **Verifizieren**: Projekt headless laden
   `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5`
   und auf `SCRIPT ERROR` / `Parse Error` prüfen. Der Stop-Hook tut das automatisch.

## Hinweise
- `@export` nur für Editor-Properties, nicht für via `setup()` gesetzte Vars.
- Resource-Properties direkt zugreifen (`good.is_contraband`), nicht `.get(...)`.
- Beim Entfernen von `@export`-Feldern aus Resource-Skripten: entsprechende Zeilen
  in ALLEN `.tres` unter `data/` mitlöschen.
