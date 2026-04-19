# Crew-Einfluss auf Missionen — Design

Date: 2026-04-19
Source: ROADMAP.md → Backlog → "Crew-Einfluss auf Missionen"

## Goal

Die in `crew_data.gd` vorhandenen Felder (`event_flavor_tag`, `EVENT_SKILL`, `QUEST_NEGOTIATION`, `COMBAT_TACTICAL`) wirken zur Laufzeit. Crew soll während Combat, Mission, Casino und Customs spürbar und sichtbar helfen.

## Status Quo

Bereits verdrahtet:
- `EVENT_SKILL` → `get_event_success_bonus()` in Planet- und Travel-Events.
- `QUEST_NEGOTIATION` → `quest_manager.gd:152` (+1 Deadline, +10% Reward bei Quest-Erstellung).
- `event_flavor_tag` → Flavor-Text in Events; Rival-Combat (+2 Dmg auf 1. Angriff bei `combat`-Tag).
- Space Invaders nutzt `ATTACK_BONUS`, `ENCOUNTER_REDUCTION`, `COMBAT_HEAL` (jeweils Primär-Bonus).
- Customs: `SMUGGLE_PROTECTION` reduziert Scan-Chance, erhöht Hide- und Bribe-Chance.

Bug:
- `card_battle.gd:495-496` prüft `COMBAT_TACTICAL` über `has_crew_bonus()` / `get_crew_bonus_value()`. Diese Helfer lesen nur den **Primär**-Bonus. `COMBAT_TACTICAL` ist auf Weapons Officer als **Sekundär** gesetzt → der Tactical-Dodge feuert nie.

## Scope

### 1. Bug-Fix: Tactical Dodge

`card_battle.gd:494-498` umstellen auf Sekundär-Lookup über neuen Helfer `GameManager.get_combat_tactical_dodge_chance()`.

### 2. Neue Wirkungen

| Crew | Wirkung | Hook |
|---|---|---|
| Medic | +1 HP/Turn ab Turn 2, gecapped auf `max_hull` | `card_battle._start_player_turn()` |
| Engineer | +1 Shield/Turn ab Turn 2, gecapped auf `max_shield` | `card_battle._start_player_turn()` |
| Navigator | Mission: enemy bullet speed × 0.85 | `space_invaders._init_game()` |
| Trader | Slots 3x-Skull-Extra-Loss × 0.80 | `casino_popup` (Slots-Result-Branch) |
| Smuggler | Customs: +0.05 zur Bribe-Chance (zusätzlich zur bestehenden +0.08 aus `SMUGGLE_PROTECTION`) | `customs_scan._get_bribe_success_chance()` |

Begründung für Turn-2-Cooldown bei Medic/Engineer: vermeidet „free start-of-fight buff" und macht den Bonus über längere Kämpfe wertvoller.

### 3. Sichtbarkeit (Toasts, Stil A)

Combat (`card_battle._show_battle_message`):
- Tactical Dodge: „Tactical Dodge! Enemy first attack misses." (ersetzt bestehende Message)
- Medic: „Medic patches +1 HP" (nur wenn Heal tatsächlich appliziert wurde, also nicht bei vollem Hull)
- Engineer: „Engineer reroutes power +1 shield" (nur wenn Shield tatsächlich appliziert wurde)

Mission (`space_invaders`):
- Beim Setup eine kurze, kombinierte Status-Zeile im `_info_label` für ~2s, die alle aktiven Crew-Boni listet, bevor das normale „Enemies: N" einsetzt.

Casino (Slots Skull-Branch):
- Result-Message erweitert: „3x Skull! Lost N cr (Trader cushioned the loss)."

Customs:
- Bribe-Button-Label zeigt inline die Smuggler-Quote: z. B. „Bribe Official (Xcr, Y% success — Smuggler edge)".

### 4. Architektur

Helfer in `GameManager` (zentral, damit Szenen-Code nichts über Bonus-Typen wissen muss):

```gdscript
func get_combat_heal_per_turn() -> int
func get_combat_shield_regen_per_turn() -> int
func get_combat_tactical_dodge_chance() -> float
func get_mission_enemy_bullet_speed_mult() -> float
func get_casino_loss_mult() -> float
func get_customs_bribe_bonus() -> float
```

Implementierung: Lookup über `crew[]` nach passendem Primär- bzw. Sekundär-Bonus. `get_combat_tactical_dodge_chance()` summiert `secondary_bonus_value` über alle Crew mit `secondary_bonus_type == COMBAT_TACTICAL` (gecapped bei 0.6, falls jemand mehrere stapelt — derzeit nur Weapons Officer).

### 5. Datei-Änderungen

- `scripts/autoloads/game_manager.gd` — 6 neue Helfer
- `scripts/scenes/card_battle.gd` — `_start_player_turn` (Heal/Shield), `_on_end_turn_pressed` (Dodge-Fix)
- `scripts/scenes/space_invaders.gd` — `_init_game` (bullet speed mult), `_build_ui` oder `_init_game` (Crew-Status-Zeile)
- `scripts/components/casino_popup.gd` — Slots Skull-Branch
- `scripts/components/customs_scan.gd` — `_get_bribe_success_chance` und Button-Label

### 6. Out of Scope

- Kein neues Crew-Mitglied, keine neuen `.tres`-Dateien
- Kein neuer Resource-Property, keine Save-Manager-Änderung (alles vom Crew-Roster abgeleitet)
- Kein persistentes Crew-Bonus-Panel-UI im Combat
- Kein Refactor der bestehenden Primär-Bonus-Doppel­belegungen (Space Invaders nutzt ATTACK_BONUS = Schussrate, ENCOUNTER_REDUCTION = +1 Leben, COMBAT_HEAL = weniger Hull-Schaden — bleibt)

### 7. Tests

Manuell:
- Combat mit Weapons Officer: Tactical-Dodge-Toast feuert ungefähr in 20 % der Kämpfe in Runde 1.
- Combat mit Medic: ab Turn 2 +1 HP-Toast, kein Toast bei vollem Hull.
- Combat mit Engineer: ab Turn 2 +1 Shield-Toast, kein Toast bei vollem Shield.
- Combat mit Medic + Engineer: beide Toasts in derselben Runde.
- Mission mit Navigator: Bullets fliegen sichtbar langsamer.
- Casino Slots mit Trader, 3x Skull: Loss-Text erwähnt Trader.
- Customs mit Smuggler: Bribe-Button zeigt „Smuggler edge".
- Ohne Crew: keine Toasts, kein veränderter Mission-Speed, keine veränderten Texte.
