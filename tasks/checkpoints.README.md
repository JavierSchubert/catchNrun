# Checkpoints — Implemented

Status of work that already exists in the repository, relative to `docs/` and the first milestone in `docs/instructions.README.md`.

Use this file together with `working_packages.README.md` to compare done vs open work.

Last reviewed: **2026-11-21** (UI / audio / settings dock + camera bound padding + lobby ENet presentation).

---

## How to read this file

| Status | Meaning |
| --- | --- |
| Done | Behavior exists and matches the owning doc for the scoped milestone |
| Partial | Present but incomplete vs the full doc |
| Scaffold only | Enum, field, folder, or config exists without gameplay behavior |

---

## Changelog (when)

| Date | Checkpoint / scope | What landed |
| --- | --- | --- |
| 2026-11-19 | Tasks folder created | Initial `checkpoints.README.md` + `working_packages.README.md` audit of existing session/multiplayer skeleton (CP-01 … CP-07 as of that audit) |
| 2026-11-19 | **CP-08** Basic melee combat | Health component; host melee; Hunter 25 / Runner 0 damage; hunter bot chase+attack; elimination → observer; `Phase.ENDED` win/loss |
| 2026-11-19 | CP-03 / CP-04 / CP-05 / CP-06 updates | Match end + observer; free edge-scroll camera + `C` center; runtime HP/damage stats; hunter-bot hunt behavior; melee test scene |
| 2026-11-19 | CP-04 move feedback | Right-click ground shows a short tweened move-click ring (`src/fx/move_click_marker.gd`) |
| 2026-11-19 | CP-04 move marker tests | Headless FX test + runner: `tests/fx/move_click_marker_test.tscn`, `scripts/test/move_click_marker_test.ps1` |
| 2026-11-20 | CP-03 / CP-04 unit presentation and map | Selectable Runner/Hunter sprites; shared inherited Unit scene with health bars sized to sprites; lava map; units clamped inside map bounds; circular collision shapes smaller than sprites; camera zoom factor 5.0 (configurable) and edge margin 300; session presentation tests |
| 2026-11-20 | CP-04 camera zoom configuration | Removed the match-scene zoom override so the exported `zoom_factor` in `match_camera.gd` controls the camera; default is now 1.0 and changes apply directly to `Camera2D.zoom` |
| 2026-11-20 | **CP-09** Entity selection | Left-click / drag-box selection; hover + selected circles (green own / blue runner team / red hunter); own-group control gating; priority resolver + headless test |
| 2026-11-20 | **CP-10** Selection panel + minimap HUD | Bottom selection strip (circular portrait + stats); bottom-left minimap with lava map asset + unit pixels; `C` always centers on own unit |
| 2026-11-20 | **CP-11** Grid building foundation | `building.README.md`; physics layers; BuildGrid / PlacementValidator / Building footprint=hitbox; interactive + headless construction tests |
| 2026-11-21 | **CP-12** UI, audio, settings, camera padding | `SettingsManager` / `SoundManager`; Music+SFX buses; persistent playlist; settings dock on every scene; lobby ENet-only UX; sandbox chrome layout; `MatchCamera.bound_padding` (zoom-aware overscroll) |

Older CP-01 … CP-07 rows without a date above were already present before this tracking file existed; the 2026-11-19 audit only recorded their status, not their original land date.

---

## CP-01 — Project and session skeleton

| Item | Status | Evidence |
| --- | --- | --- |
| Runnable Godot 4.7 project | Done | `project.godot` |
| Autoload stack | Done | `LaunchOptions`, `NetworkManager`, `GameManager`, `SceneTransitionManager`, `SettingsManager`, `SoundManager`, `BotClient`, `Sandbox` |
| Scene transitions only via manager (`from` → `to`) | Done | `autoloads/scene_transition_manager.gd` |
| Direct scene open for isolated tests | Done | `--scene=lobby\|selection\|game`, empty `from` supported |
| Lobby (s0) host / join / roster / continue (ENet UI) | Done | `ui/lobby/` — Host/Join local; Steam host buttons removed from lobby |
| Role selection (s1) left Runners / right Hunter | Done | `ui/role_selection/` |
| Exactly one Hunter; random among Hunter requests; random if none | Done | `GameManager.choose_hunter_id` |
| Game (s2) match scene | Done | `game/match/` |
| Each session screen testable alone | Done | Launch options + sandbox open buttons + session tests |

**Doc owners:** `gameplay.README.md` §2, `project_architecture.README.md` §6.2–6.3, `instructions.README.md` §2 / §7

---

## CP-02 — Multiplayer networking

| Item | Status | Evidence |
| --- | --- | --- |
| ENet host / join on localhost | Done | `autoloads/network_manager.gd` |
| Host-authoritative roster and RPCs | Done | `autoloads/game_manager.gd` |
| Clients send intent, host applies | Done | Movement orders, side votes, skip prep |
| Peer disconnect handling → lobby | Done | `_on_peer_left`, `_on_disconnected` |
| Steam lobby / invite path | Partial | Still in `network_manager.gd`; **not** exposed in lobby UI (ENet-only presentation) |
| Public matchmaking / lobby browser | Not in scope yet | Explicit exclusion in architecture §7.4 |

**Doc owners:** `project_architecture.README.md` §7, `instructions.README.md` §2

---

## CP-03 — Match lifecycle

| Item | Status | Evidence |
| --- | --- | --- |
| Phases: Lobby → Role Selection → Runner Preparation → Hunter Active | Done | `GameManager.Phase` |
| Configurable head start (default 60s) | Done | `src/match/match_config.tres`, CLI `--head-start` |
| Preparation timer + host skip | Done | `_process`, `request_skip_preparation` |
| Wait until all peers report scene ready | Done | `report_scene_ready`, `all_players_loaded` |
| Runners spawn in preparation | Done | `game/match/match.gd` |
| Hunter spawns only after preparation ends | Done | `_spawn_pending` + `HUNTER_ACTIVE` |
| Role-specific selectable Runner / Hunter sprites | Done | `ui/role_selection/`, `src/units/unit/unit.gd`, `GameManager` sprite index |
| Shared health bar on each Runner / Hunter | Done | `src/units/unit/unit.tscn`, `ui/hud/health_bar/` |
| Lava map background (`arena_plateau` / tiles v3) | Done | `game/maps/arena_plateau.tscn`, `game/match/match.tscn` (not space atlas) |
| Minimal match HUD (phase, timer, local role / HP / observer) | Done | `game/match/hud.gd` (status top-center under sandbox action bar) |
| Reset match to lobby | Done | `GameManager.reset_match` |
| Match / network logging | Done | `src/logging/game_log.gd` |
| Match finished / win-loss (`Phase.ENDED`) | Done | `GameManager._finish_match` when all Runners or Hunter are down |
| Player `alive` / elimination → observer | Done | `eliminate_player`; dead local player keeps free camera |

**Doc owners:** `gameplay.README.md` §3–§6, `project_architecture.README.md` §6.4

---

## CP-04 — Units, movement, navigation

| Item | Status | Evidence |
| --- | --- | --- |
| Shared `Unit` CharacterBody2D scene inherited by Runner / Hunter | Done | `src/units/unit/unit.tscn`, `src/units/unit/unit.gd` |
| Right-click move intent → host path order | Done | `_unhandled_input`, `_submit_move_order` |
| Host simulates movement; clients interpolate | Done | `unit.gd` + `src/navigation/movement.gd` |
| Units and requested move destinations stay inside map bounds | Done | `Unit._clamp_to_map`; bounds match the lava background |
| Circular collision shape smaller than the selected sprite | Done | `src/units/unit/unit.tscn` |
| Path follow + replace current order | Done | `path_follow.gd`, `movement.order_move` |
| Movement speed driven by stats | Done | `StatSheet` → `UnitMovement.speed` |
| Free match camera with edge scroll + `C` center, map-aware bounds, configurable zoom (default 1.0), edge margin 300 | Done | `game/camera/match_camera.gd`, `game/match/match.tscn` |
| Camera overscroll padding (`bound_padding`, default 360 screen px, zoom-aware) | Done | Map corners stay inset; units at map edge remain readable — see `controls.README.md` §2.2 |
| Right-click move marker (pop + fade) | Done | `src/fx/move_click_marker.gd` (local only) |
| Move-marker automated tests | Done | `tests/fx/move_click_marker_test.gd` |
| Straight-line paths (no obstacles) | Partial | `navigation_paths.gd` stub; no walls yet |
| Move-command automated tests | Done | `tests/navigation/move_command_test.gd` |

**Doc owners:** `controls.README.md` §1.2 / §2 camera subset, `project_architecture.README.md` § navigation

---

## CP-05 — Stats calculation

| Item | Status | Evidence |
| --- | --- | --- |
| Supported stats per `stats.README.md` | Done | `src/stats/stat_block.gd` |
| Flat + percentage modifiers; `ALL_DAMAGE` scope | Done | `src/stats/stat_modifier.gd` |
| Final value formula + chance / non-neg constraints | Done | `src/stats/stat_sheet.gd` |
| Role base stats as resources | Done | `hunter_config.tres`, `runner_config.tres` |
| Automated calculation tests (incl. docs example) | Done | `tests/stats/stat_calculation_test.gd` |
| Runtime health from `max_health` | Done | `HealthComponent` + unit sync |
| Hunter melee damage / Runner damage `0` | Done | Role configs + `CombatDamage` |
| Crit / lifesteal / defense / regen consumed in melee | Partial | Wired in `CombatDamage` / regen tick; defaults currently 0 for clear fights |

**Doc owners:** `stats.README.md` §1–§2

---

## CP-08 — Basic melee combat

| Item | Status | Evidence |
| --- | --- | --- |
| Health component | Done | `src/components/health/health_component.gd` |
| Host melee swing + acquisition / attack range | Done | `src/combat/attack_controller.gd`, `unit.gd` |
| Right-click attack command with chase | Done | Unit input + `_submit_attack_target` |
| Hunter bot chases / attacks nearest Runner | Done | `_hunter_bot_chase` |
| Elimination + observer + match end | Done | `GameManager.eliminate_player`, HUD observing text |
| Melee damage automated tests | Done | `tests/combat/melee_damage_test.gd` |

**Still open:** attack-move, hitbox/hurtbox scenes, ranged/magic projectiles — see WP-01.

---

## CP-09 — Entity selection

| Item | Status | Evidence |
| --- | --- | --- |
| `src/selection/` manager + resolver + circle + drag box | Done | `selection_manager.gd`, `selection_resolver.gd`, `selection_circle.gd`, `drag_select_box.gd` |
| Left-click select / clear on empty ground | Done | `SelectionManager` point selection |
| Hold-drag transparent selection rectangle | Done | `DragSelectBox` + drag threshold |
| Hover thin circle → selected thick circle | Done | `SelectionCircle` hover/selected widths |
| Colors: own green / runner-team blue / hunter red | Done | `SelectionCircle` + `Unit._selection_circle_color` |
| Selectable vs controllable (own group only) | Done | Right-click gated by `SelectionManager.is_controllable_selected` |
| Priority: own → player figures → NPC; else random | Done | `SelectionResolver` + `tests/selection/selection_priority_test.gd` |
| Spec in controls doc §1.1 | Done | `docs/controls.README.md` |
| Selection Panel HUD | Moved to CP-10 | Minimal portrait + stats strip |

**Doc owners:** `controls.README.md` §1.1 / §3.1, `project_architecture.README.md` § `src/selection/`

---

## CP-10 — Selection panel and minimap HUD

| Item | Status | Evidence |
| --- | --- | --- |
| Bottom selection strip with circular portrait + stats | Done | `ui/hud/selection_panel/selection_panel.gd` |
| Portrait ring uses selection affinity colors | Done | Own green / runner blue / hunter red |
| Shows selected HP / speed / melee / defense + controllable flag | Done | Bound from `SelectionManager` each frame |
| `C` always centers on local own unit (ignores foreign selection) | Done | `game/camera/match_camera.gd`, `controls.README.md` §1.4 |
| Bottom-left minimap with current map asset | Done | `ui/hud/minimap/minimap.gd` + lava texture |
| Unit pixels at relative world positions | Done | Mapped via `Unit.MAP_BOUNDS` |
| Pixel colors match selection circles | Done | Own green / other runners blue / hunter red |
| Spec updates | Done | `minimap.README.md` §2.1, `selection_panel.README.md` §2 |

**Still open:** fog-of-war filtering on minimap, context-action buttons, cursors — see WP-04 / WP-05.

**Doc owners:** `selection_panel.README.md`, `minimap.README.md`, `controls.README.md` §1.4

---

## CP-11 — Grid building foundation

| Item | Status | Evidence |
| --- | --- | --- |
| Building README (grid, footprint=hitbox, layers) | Done | `docs/building.README.md` |
| Construction doc points at grid placement | Done | `docs/construction.README.md` §2 |
| Physics layers world/obstacle/unit/building/destructible/item | Done | `project.godot` + `src/construction/physics_layers.gd` |
| Build grid + placement validator | Done | `build_grid.gd`, `placement_validator.gd` |
| Building footprint spawns matching rect hitbox | Done | `src/buildings/building.gd` / `building.tscn` |
| Interactive grid placement test scene | Done | `tests/construction/building_grid_test.tscn` |
| Headless footprint / blocker-mask tests | Done | `tests/construction/build_grid_logic_test.gd` |

**Still open:** Crystal Mine / Wall / Tower content, match build menu, economy spend, nav updates — WP-02.

**Doc owners:** `building.README.md`, `construction.README.md`

---

## CP-06 — Sandbox, bots, tests

| Item | Status | Evidence |
| --- | --- | --- |
| Debug sandbox panel | Done | `game/sandbox/sandbox_panel.gd` |
| Top-left action bar (compact) + Runner/Hunter sample icons | Done | Host, bots, quick start, continue, skip, reset; headless **on by default** |
| Top-right Tests panel | Done | Open lobby / roles / game alone (clears sandbox action bar) |
| Bottom-right status | Done | Phase, peers, last action |
| Host, add bots, quick-start 1H+2R | Done | Sandbox actions |
| Skip preparation / reset / open s0–s2 alone | Done | Sandbox actions |
| Peer / role / phase inspection | Done | Sandbox refresh UI |
| Bot client: connect, vote, spawn, move, disconnect | Done | `tests/bots/bot_client.gd` |
| Hunter bot chase / attack behavior | Done | `Unit._hunter_bot_chase` (Runner bots still circle) |
| Multiplayer smoke test | Done | `scripts/test/smoke_test.ps1` |
| Session / stats / move / melee / selection test runners | Done | `scripts/test/*.ps1` |
| Lobby + role-selection scene test | Done | `tests/session/lobby_and_selection_test.gd` |
| Full god-mode checklist (structures, crystals, fog, damage) | Partial | Networking-focused only |

**Doc owners:** `instructions.README.md` §4–§7, `project_architecture.README.md` §8–§10 (subset), `ui_audio.README.md` §6

---

## CP-07 — Architecture scaffolding present

| Present | Notes |
| --- | --- |
| `autoloads/` (+ `SettingsManager`, `SoundManager`) | Active |
| `src/units`, `src/navigation`, `src/stats`, `src/match`, `src/logging`, `src/combat`, `src/components/health`, `src/selection`, `src/construction`, `src/buildings` | Active implementation |
| `game/match`, `game/maps`, `game/sandbox`, `game/camera` | Active |
| `ui/lobby`, `ui/role_selection`, `ui/widgets/`, `ui/hud/{health_bar,selection_panel,minimap}` | Active |
| `default_bus_layout.tres` (Master → Music / SFX) | Wired in `project.godot` |
| `tests/{bots,session,stats,navigation,combat}`, `scripts/test/` | Active |
| `addons/godotsteam`, Web preset in `export_presets.cfg` | Present; export path / CI still open |
| Empty leftover dirs (`components/`, `common/`, `data/`, …) | Legacy experimental code removed; not gameplay features |

---

## CP-12 — UI presentation, audio, and settings

| Item | Status | Evidence |
| --- | --- | --- |
| Audio bus layout Master → Music / SFX | Done | `default_bus_layout.tres` + `project.godot` `[audio]` |
| `SoundManager` playlist + SFX pool | Done | `autoloads/sound_manager.gd`; MP3 via raw bytes when imports invalid |
| Persistent playlist across scene changes | Done | `ensure_music()` / `play_music` only switches on track change |
| Boot music (osrs_bh1 → bh2 → bh3 loop) | Done | Deferred `ensure_music` from Settings / SoundManager |
| Volume + mute persisted | Done | `SettingsManager` → `user://settings.cfg` |
| Settings dock (gear) on lobby / roles / match | Done | `ui/widgets/settings_menu/` + `SettingsMenu.attach` |
| Animated buttons + UI click SFX | Done | `ui/widgets/animated_button/`, `SoundManager.play_ui` |
| Lobby branded card, ENet-only host/join | Done | `ui/lobby/lobby.gd` |
| Sandbox chrome non-overlapping layout | Done | Action TL / Tests TR / Status BR; HUD under action bar |
| Camera bound padding (overscroll) | Done | `MatchCamera.bound_padding` default `360` screen px |
| Config documented | Done | `docs/ui_audio.README.md`, `README.md` runtime section, `controls.README.md` §2.2 |

**Doc owners:** `ui_audio.README.md`, `controls.README.md` §2, root `README.md` runtime configuration

---

## First milestone verdict

Per `docs/instructions.README.md` Definition of Done, the **session + multiplayer technical skeleton is largely complete**. Basic melee combat, hunter-bot hunting, elimination/observer, free camera edge-scroll with overscroll padding, and persistent UI/audio settings are also in.

Still open in `working_packages.README.md`: economy, full structure content (mines/walls/towers), attack-move / advanced combat, fog of war (minimap FoW), shop, cursors, and selection context-actions. Grid building foundation is CP-11; UI/audio/settings presentation is CP-12.
