# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpaceTrader is a 2D roguelike space trading + deck-building card game built with **Godot Engine 4.6** (GL Compatibility renderer) using **GDScript**. Players trade goods across planets, build a combat deck, upgrade their ship, and complete quests. Win condition: accumulate 8000 credits AND visit all 7 planets.

## Running the Project

- Open in Godot 4.6 editor (Import → point to this directory)
- Press F5 to run (main scene: `res://scenes/main_menu.tscn`)
- Window: 1280x720 game resolution, 2560x1440 window override
- No external dependencies — pure Godot engine
- No automated test suite; testing is manual play-through
- Export presets in `export_presets.cfg` (Windows, iOS, macOS configured)

## Architecture

### Autoload Singletons (`scripts/autoloads/`)

Nine global managers registered in `project.godot` provide centralized game state:

- **GameManager** — Player state: credits, hull/shields, cargo inventory, deck, upgrades, crew (max 3), current planet, visited planets. Emits signals on state changes (credits, cargo) for UI binding. `reset()` method centralizes all game state reset — always use `GameManager.reset()` for new games, never duplicate reset logic in scene scripts.
- **EconomyManager** — Dynamic pricing with planet-type modifiers (5 types: Tech, Industrial, Agricultural, Mining, Outlaw). Prices drift ±5% on departure, ±10% variance. Contraband goods (Spice, Stolen Tech) have special pricing. Sell ratio is 75% of buy price.
- **EncounterManager** — Enemy encounter pool with difficulty scaling (+1 per 2 visited planets). Contraband cargo increases encounter chance by 15%.
- **QuestManager** — Procedural quest generation with delivery deadlines (3-5 turns) and penalties (40% of reward if missed). One active quest at a time.
- **SaveManager** — JSON serialization to `user://savegame.json`. Cards saved by resource path. Also saves/restores quest state (`current_quest`, `available_quests`) and event manager state.
- **EventLog** — 50-entry ring buffer of game events.
- **EventManager** — Dynamic world events (blockades, harvests, tech booms). 30% trigger chance on departure, 3-5 turn duration. Modifies prices, encounter chance, sell ratio, combat rewards. API: `get_price_modifier()`, `get_encounter_modifier()`, `get_sell_ratio_override()`, `get_reward_modifier()`, `get_event_display_text()`. Shown as news banner on planet screen.
- **ResourceRegistry** — Centralized `.tres` resource path registry. `DirAccess` cannot list files in exported PCK archives, so all resource paths are hardcoded here. Helper: `load_all(paths) -> Array`. Constants: `PLANETS`, `GOODS`, `CARDS`, `ENCOUNTERS`, `UPGRADES`, `CREW`, `PLANET_EVENTS`.
- **ScreenFade** — Global scene transition fade effects.

### Resource Data Pattern (`scripts/resources/` + `data/`)

Game data uses Godot `.tres` (text Resource) files with custom resource classes:
- `CardData` — attack/defense/utility/trade cards with energy cost, damage, shield, heal, draw, and special effects
- `PlanetData` — name, type, connections, danger level, available goods
- `GoodData` — tradeable goods with base price and contraband flag
- `EncounterData` — enemy name, HP, damage range, credits reward
- `ShipUpgradeData` — upgrade cost, stat bonuses, card additions
- `CrewData` — crew members with bonus type (6 types: encounter reduction, attack, hull regen, sell bonus, smuggle protection, max hull), recruit cost, available planet types
- `PlanetEventData` — planet arrival events with two-choice decisions and consequences (credits/hull/cargo)

All data lives in `data/{cards,planets,goods,encounters,upgrades,crew,planet_events}/` and is loaded via `ResourceRegistry` (see below).

### Scene + Controller Pattern

Each game screen is a `.tscn` scene paired with a controller script in `scripts/scenes/`. Reusable UI components live in `scenes/components/` + `scripts/components/`.

### Communication

Signal-based: managers emit signals, UI components subscribe. Scene transitions go through `ScreenFade` autoload.

## Core Game Systems

**Combat** (`card_battle.gd`): Energy-based card play (3-5 energy/turn), hand size 5, draw from deck with discard shuffle. Enemy intent is telegraphed. Shield carries over from overworld (not reset to 0). Card special effects: scavenge, skip enemy turn, self-damage, bonus energy, etc. Scavenge animation tuned to 1.0s delay, 1.8s tween, 0.4s fade.

**Trading**: Buy goods at one planet, sell at another. Planet types affect which goods are cheap/expensive. Contraband is high-risk/high-reward. Price comparison arrows (green ▼ cheap / red ▲ expensive / gray — average) shown via `avg_price` parameter in `cargo_slot.gd`, powered by `EconomyManager.get_average_price()`.

**Ship Upgrades** (`shipyard_panel.gd`): Compact panel with live `ShipDisplay` (80x80) and upgrade buttons. Hull repair (8cr/HP), +5 max hull (200cr), +3 max shield (250cr), +2 cargo (300cr), plus card-adding upgrades, energy/hand size bonuses. Emits `shipyard_action` signal.

**Ship Display** (`ship_display.gd`): Procedural ship rendering with `_draw()` — no sprites. 6 layers: shield bubble, hull polygon (color by HP%), cockpit, engine, damage cracks (<60% hull), cargo fill. API: `update_ship(hull_pct, shield_pct, cargo_used, cargo_max)`. Used in planet screen (80x80) and battle screen (80x90).

**Planet Background** (`planet_background.gd`): Procedural planet with `_draw()` — atmosphere, body, surface bands, highlight, shadow, optional moon. 5 color schemes by planet type. API: `setup(planet_type: int)`. Shown on planet screen (120x100).

**Space Background** (`space_background.gd`): Procedural starfield behind entire planet screen via `_draw()` + `_process()`. ~150 static stars (3 size classes), 7-9 nebula clouds tinted by planet atmosphere color, 15-20 twinkling stars with glow halos (sine-wave pulse). Deterministic seed per planet type. Danger level shifts colors redward and darkens nebulae. API: `setup(planet_type: int, danger_level: int)`. UI panels use 0.75 alpha so the background shines through.

**Smuggler Events** (`smuggler_event.gd`): 15% chance on planet arrival. Offers discount buy or premium sell deals. 25% chance of getting caught → 50-150cr fine. Modal popup overlay, emits `deal_closed` signal. Instantiated in `planet_screen._ready()`.

**Crew** (`crew_panel.gd`): Recruit/dismiss crew members (max 3). Six bonus types that passively affect gameplay (encounter reduction, attack bonus, hull regen, sell bonus, smuggle protection, max hull). Planet type determines which crew are available. Data in `data/crew/`.

**Planet Events** (`planet_event.gd`): 25% chance on planet arrival. Modal popup with two choices and consequences (credits/hull/cargo gains or losses). Data in `data/planet_events/`.

**Quest System** (`quest_manager.gd`): One active quest at a time. Each planet offers a random delivery quest (1-3 items, 3-5 turn deadline). `tick()` called on departure decrements `turns_left`. `check_expired_quest()` called on planet arrival (after battle credits) — if expired and player can't pay penalty → Game Over. This ordering ensures battle rewards count before penalty check. Manual delivery via button at target planet. UI in `quest_display.gd`.

**Navigation**: 7 planets in a connection graph. Travel triggers encounter chance based on destination danger level. Galaxy map info panel shows available trade goods per planet on hover (`galaxy_map.gd` → `_on_planet_hovered()`).

### Planet Screen Layout

3-column layout:
- **Left**: MarketPanel + CargoPanel (stacked)
- **Middle**: CrewPanel
- **Right**: PlanetBackground + ShipyardPanel + QuestDisplay
- **Top**: News banner (EventManager world events)
- **BottomBar**: Credits, cargo capacity, hull, shield, Save, View Deck, Depart

## Adding Game Content

- **New card**: Create `.tres` in `data/cards/` using `CardData` resource class
- **New planet**: Create `.tres` in `data/planets/` using `PlanetData`, update connection graph in other planets
- **New encounter**: Create `.tres` in `data/encounters/` using `EncounterData`
- **New good**: Create `.tres` in `data/goods/` using `GoodData`, update `EconomyManager` planet-type pricing
- **New upgrade**: Create `.tres` in `data/upgrades/` using `ShipUpgradeData`
- **New crew member**: Create `.tres` in `data/crew/` using `CrewData` resource class
- **New planet event**: Create `.tres` in `data/planet_events/` using `PlanetEventData` resource class

**Important**: After creating a new `.tres` file, add its path to `ResourceRegistry` (`scripts/autoloads/resource_registry.gd`). `DirAccess` cannot list files inside exported PCK archives — all resource paths must be registered explicitly.

**Important**: When removing `@export` fields from resource scripts, also remove the corresponding lines from all `.tres` files in `data/` — Godot may warn or error on unknown properties.

## Design Documentation

`PLAN.md` contains the implementation plan (in German) for all 8 shipped features with detailed descriptions, file lists, APIs, integration points, and a summary of all new/modified files. Consult it for feature-level context.

## Game Flow: Departure → Arrival

1. **Depart** (`planet_screen.gd`) → `QuestManager.tick()` (deadline -1), `EventManager.tick()`, `EconomyManager.tick_economy()`
2. **Galaxy Map** → player picks destination → `travel_scene.tscn`
3. **Travel** → possible encounter → `card_battle.tscn` → battle credits awarded → `battle_result.tscn`
4. **Arrival** (`planet_screen._ready()`) → `QuestManager.check_expired_quest()` (penalty/game over) → UI setup

## UI Style Notes

- Panel backgrounds use **0.75 alpha** (`Color(0.08, 0.1, 0.14, 0.75)`) so the procedural space background is visible behind UI elements
- Consistent button style: costs shown in parentheses in button text, e.g. `"Repair Hull (48cr)"`, `"+5 Max Hull (200cr)"`
- Most UI components are built programmatically in `_build_ui()` or `_ready()` — nodes created via code, not in `.tscn`. Only the root container is defined in the scene file. Examples: `quest_display.gd`, `crew_panel.gd`, `shipyard_panel.gd`.

## GDScript Conventions

- snake_case for variables/functions, PascalCase for classes
- `@onready` for node references, `@export` for editor-exposed properties
- Signals declared with `signal name(params)` at top of class
- Always type-annotate variables: `var res: Resource = load(path)`, not `var res = load(path)`
- `_underscore` prefix = private. Never call `_private_method()` from other scripts
- Use `@export` only for editor-exposed properties, not for vars set via `setup()` at runtime
- Access Resource properties directly (`good.is_contraband`), not via `.get("is_contraband")`
- Shared constants (e.g. planet type names) belong in one autoload, not duplicated across files
- `EconomyManager.PLANET_TYPE_NAMES` is the single source for planet type name mapping

## Communication

- Der Benutzer kommuniziert auf Deutsch. Antworten auf Deutsch. 
- Quellcode ist auf Englisch, inkl. der Kommentare.
