# Checkpoints — Implemented

Status of work that already exists in the repository, relative to `docs/` and the first milestone in `docs/instructions.README.md`.

Use this file together with `working_packages.README.md` to compare done vs open work.

Last reviewed: **2026-11-26** (WP-14 / CP-19 Hunter XP + portrait XP ring — code-reviewed, no Godot run).

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
| 2026-11-21 | **CP-13** Editor-preview scenes + style resources | Match HUD / selection panel / minimap / lobby / role selection as `.tscn` shells; shared `ui/styles/*.tres` StyleBoxes; unit default sprites in Hunter/Runner scenes; arena props + spawn gizmos; optional `ui/widgets/ui_kit/ui_kit.tscn` |
| 2026-11-21 | CP-03 / CP-04 / CP-10 camera + minimap UX | Center spawn ring (`PlateauMap.spawn_ring_positions`); viewer-relative minimap colors; camera frustum + LMB jump on minimap; no edge-scroll over UI; no auto-recenter on eliminations / roster noise |
| 2026-11-21 | CP-10 selection panel combat HUD | Fixed-size panel; clean stat icons; 2×3 combat grid; health bar + regen; empty = grey box + empty ring |
| 2026-11-21 | CP-02 networking cleanup | Removed `addons/godotsteam` and all Steam lobby / invite paths; `NetworkManager` is ENet-only |
| 2026-11-22 | **CP-14** Attack UX, chains, camera, sandbox | Right-click attack (red ring); A+LMB attack-move; Shift+RMB green move chain; Shift+A+LMB red attack-move chain (mixable); chain path outranks in-range auto-attack; minimap RMB / Shift+RMB / A+LMB / Shift+A+LMB; MMB camera drag; faster edge-scroll (`camera_speed` 1600, `edge_margin` 48); sandbox Reset fixed (deferred lobby + null-safe multiplayer); scrollable GameLog panel |
| 2026-11-25 | **CP-15** Match-integrated construction + Crystal economy | Bottom-right build UI (`ui/hud/building_panel/`) with clickable per-structure icons, grid ghost preview, Upgrade / Destroy for owned selection; `ConstructionManager` (host-authoritative build/upgrade/destroy RPCs + `BuildingSpawner`); data-driven `BuildingDef` (cost/HP/build-time scale with level) backing Wall / Tower / Crystal Mine scenes sharing one `Building` script; non-instant construction with a replicated progress bar; `EconomyConfig` + `GameManager` Crystal balance (`crystals_for` / `try_spend_crystals` / `grant_crystals`, reset to 1,000,000 each match); Crystal Mine ticks owner income (`2^(level-1)` per docs/economy.README.md); Tower auto-attacks Hunters in range; Hunter melee now also damages attackable buildings; Walls (and all structures) physically block unit movement (`Unit` collision mask); headless `tests/construction/building_economy_test` + interactive `tests/construction/building_system_test`. *Balance superseded by CP-16 (20 starting Crystals, mine `2 * 2^(level-1)`).* |
| 2026-11-26 | **CP-16** Crystal rebalance, Tower projectiles, Wall shield, Runner repair (WP-16 A–D) | **Code-reviewed only — not yet run in Godot.** Starting Crystals 20; costs Mine 16 / Wall 8 / Tower 24 ×1.8 per level, max Lv 11 / 20 / 20; mine 2 → 2048; Hunter earns 0.2 Crystals per applied damage (both melee sites); top-center Crystal HUD for both roles with `+X/s`; Tower on `StatSheet` with homing projectiles and one of four stat picks per upgrade (applied on completion); Wall shield from Lv 15 via `ShieldComponent` + `Building.apply_damage()`; Runner `repair` skill (RMB own damaged structure); headless `tower_projectile_test` / `repair_skill_test`, interactive `tower_combat_test` / `wall_repair_test`; economy / construction / controls / stats / building docs updated |
| 2026-11-26 | **CP-17** HUD overhaul (WP-17 A–D) | **Code-reviewed only — not yet run in Godot.** Layout unchanged (minimap BL / SelectionPanel BC / BuildingPanel BR ~300×360); `HudMode` mutual exclusion (`UNIT_BUILD` vs `BUILDING_MANAGE`); Building `SelectionCircle` + OWN-tier resolver; SelectionPanel building info; Destroy via BuildingPanel + `_server_destroy` `_can_build`; Runner A+LMB own-building destroy; Hunter RMB `_request_attack_building`; shared `stat_icon_row`; controls / selection_panel / construction / ui_audio / architecture docs updated |
| 2026-11-26 | **CP-18** Hunter structure attack + floating numbers (WP-18 A–C / WP-09) | **Code-reviewed only — not yet run in Godot.** `StructureMelee` footprint reach / approach; `AttackController` building range; Hunter chase / attack / stuck-clear / bot target buildings; building attack flash; `FloatingNumber` (DAMAGE/CRIT/LIFESTEAL/REGEN → white/yellow/green, rise+fade, MoveClickMarker-style `spawn` / `spawn_on`) wired from melee, lifesteal, regen, tower hits; controls / WP docs updated |
| 2026-11-26 | **CP-19** Hunter XP + portrait XP ring (WP-14) | **Code-reviewed only — not yet run in Godot.** `XpProgress` curve; `Unit.level`/`xp` synced; Hunter XP from melee damage; selection-panel grey double frame + violet CCW fill + level badge; Runners Lv1 full violet; sandbox XP+50 |

Older CP-01 … CP-07 rows without a date above were already present before this tracking file existed; the 2026-11-19 audit only recorded their status, not their original land date.

---

## CP-01 — Project and session skeleton

| Item | Status | Evidence |
| --- | --- | --- |
| Runnable Godot 4.7 project | Done | `project.godot` |
| Autoload stack | Done | `LaunchOptions`, `NetworkManager`, `GameManager`, `SceneTransitionManager`, `SettingsManager`, `SoundManager`, `BotClient`, `Sandbox` |
| Scene transitions only via manager (`from` → `to`) | Done | `autoloads/scene_transition_manager.gd` |
| Direct scene open for isolated tests | Done | `--scene=lobby\|selection\|game`, empty `from` supported |
| Lobby (s0) host / join / roster / continue (ENet UI) | Done | `ui/lobby/` — Host/Join local; ENet-only |
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
| Steam / GodotSteam | Removed | Addon deleted; `NetworkManager` has no Steam APIs |
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
| All players spawn on a ring around map center (no stacking) | Done | `PlateauMap.spawn_ring_positions` + `Match.spawn_ring_radius` (default 160) |
| Role-specific selectable Runner / Hunter sprites | Done | `ui/role_selection/`, `src/units/unit/unit.gd`, `GameManager` sprite index; default textures in `hunter.tscn` / `runner.tscn` (runtime still overrides by `sprite_index`; no RoleConfig tint on sprites) |
| Shared health bar on each Runner / Hunter | Done | `src/units/unit/unit.tscn`, `ui/hud/health_bar/` |
| Lava map background (`arena_plateau` / tiles v3) | Done | `game/maps/arena_plateau.tscn`, `game/match/match.tscn` (not space atlas); editor spawn preview + optional props layer |
| Minimal match HUD (phase, timer, local role / HP / observer) | Done | `game/match/hud.tscn` + `hud.gd` (layout in scene; status top-center under sandbox action bar) |
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
| Free match camera with edge scroll + `C` center, map-aware bounds, configurable zoom (default 1.0) | Done | `game/camera/match_camera.gd`, `game/match/match.tscn` |
| Edge-scroll speed + trigger zone exports | Done | `camera_speed` default `1600`; `edge_margin` default `48` (nearer screen edge) |
| Middle-mouse camera drag pan | Done | Hold MMB to drag; release to stop; pauses edge-scroll while dragging |
| Camera overscroll padding (`bound_padding`, default 360 screen px, zoom-aware) | Done | Map corners stay inset; units at map edge remain readable — see `controls.README.md` §2.2 |
| No edge scroll while cursor is over blocking UI | Done | `gui_get_hovered_control()` gate — settings dock, minimap, sandbox chrome |
| No auto-recenter on eliminations / roster updates | Done | Free camera stays put; snap only on `_ready`, `C`, or minimap LMB |
| Minimap LMB recenters camera on clicked world position | Done | `MatchMinimap` + `MatchCamera.center_on` |
| Minimap RMB / Shift+RMB / A+LMB / Shift+A+LMB commands | Done | Move, green chain, attack-move, red attack-chain via `minimap_to_world` |
| Right-click move marker (pop + fade; blue move / red attack) | Done | `src/fx/move_click_marker.gd` (local only) |
| Shift-click move / attack-move chain (green + red, mixable) | Done | `MoveChainVisual`; chain path outranks in-range auto-attack |
| Move-marker automated tests | Done | `tests/fx/move_click_marker_test.gd` |
| Straight-line paths (no obstacles) | Partial | `navigation_paths.gd` stub; no walls yet |
| Move-command automated tests | Done | `tests/navigation/move_command_test.gd` |

**Doc owners:** `controls.README.md` §1.2 / §1.3 / §2 camera subset, `minimap.README.md` §2.3, `project_architecture.README.md` § navigation

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
| Right-click attack command with chase + red target flash | Done | Unit input + `_submit_attack_target` + `MoveClickMarker` / selection flash |
| A+LMB attack-move (red ground marker) | Done | `SelectionManager.attack_move_armed` + `issue_attack_move` |
| Plain RMB cancels attack / chain (move priority) | Done | Clears explicit target + chain; auto-attack does not interrupt active player move |
| Shift-click chains outrank in-range auto-attack | Done | Active `_move_chain` skips combat acquire until waypoints finish |
| Hunter bot chases / attacks nearest Runner | Done | `_hunter_bot_chase` |
| Elimination + observer + match end | Done | `GameManager.eliminate_player`, HUD observing text |
| Melee damage automated tests | Done | `tests/combat/melee_damage_test.gd` |

**Still open:** hitbox/hurtbox scenes, ranged/magic projectiles — see WP-01.

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
| Fixed-size bottom selection strip | Done | `520×148`; empty vs selected does not resize the panel |
| Portrait ring always present | Done | Empty ring when nothing selected; sprite when a unit is selected |
| Portrait ring uses selection affinity colors | Done | Own green / runner blue / hunter red |
| Combat stats grid (2×3) with clean icons | Done | Damage / crit / defense / lifesteal / attack speed / move; `StatIcons` + `assets/sprites/stats/clean/` |
| Stat values as colored final | Done | White at base, green above, red below (`StatIcons.format_value`) |
| Health bar under stats + regen `+X` when not full | Done | Fill = current / max; regen label hidden at full HP |
| `C` always centers on local own unit (ignores foreign selection) | Done | `game/camera/match_camera.gd`, `controls.README.md` §1.4 |
| Bottom-left minimap with current map asset | Done | `ui/hud/minimap/minimap.tscn` + frame StyleBox `.tres` |
| Unit pixels at relative world positions | Done | Mapped via `Unit.MAP_BOUNDS` |
| Viewer-relative pixel colors (own green; enemies red; allied runners blue) | Done | `Unit.minimap_marker_color` — Hunter sees Runners as red |
| Camera frustum outline + equal-size own/other dots | Done | `minimap_dots.gd` |
| Spec updates | Done | `minimap.README.md` §2.1–2.3, `selection_panel.README.md` §2 |

**Still open:** fog-of-war filtering on minimap, context-action buttons, cursors — see WP-04 / WP-05.

**Doc owners:** `selection_panel.README.md`, `minimap.README.md`, `controls.README.md` §1.4 / §2

---

## CP-13 — Editor-previewable UI / unit scenes

| Item | Status | Evidence |
| --- | --- | --- |
| Match HUD as scene (status + minimap + selection panel instances) | Done | `game/match/hud.tscn`; `match.tscn` instances it |
| Selection panel / minimap StyleBox resources | Done | `ui/hud/selection_panel/*_style.tres`, `ui/hud/minimap/minimap_frame_style.tres` |
| Shared menu StyleBoxes | Done | `ui/styles/` (card, buttons, line edit, item list, side panels) |
| Lobby / role selection shell layouts in `.tscn` | Done | Dynamic rows / actions still code-filled |
| Unit default sprites for editor preview | Done | `unit.tscn` / `hunter.tscn` / `runner.tscn` |
| UI kit gallery for Margin/Scroll + widgets | Done | `ui/widgets/ui_kit/ui_kit.tscn` |
| Runtime truth stays in scripts / resources | Done | Scenes own layout + visual defaults only — see `project_architecture.README.md` §5.3 |

**Doc owners:** `project_architecture.README.md` §5.3, `ui_audio.README.md`, `selection_panel.README.md`, `minimap.README.md`

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

**Still open:** see CP-15 below for what landed; navigation still does not route around structures (straight-line paths — CP-04 §"Still open").

**Doc owners:** `building.README.md`, `construction.README.md`

---

## CP-15 — Match-integrated construction and Crystal economy

| Item | Status | Evidence |
| --- | --- | --- |
| Runner-only build UI, bottom-right (mirrors the minimap corner) | Done | `ui/hud/building_panel/` |
| Clickable per-structure images to pick what to build | Done | `src/buildings/building_icons.gd` (generated at runtime, no art dependency) |
| Grid ghost preview + collision validation while placing | Done | Reuses `BuildGrid` / `PlacementValidator` / `BuildGhost` from CP-11 |
| Host-authoritative build / upgrade / destroy requests | Done | `src/construction/construction_manager.gd`, `BuildingSpawner` |
| Runner can destroy their own structures from the build UI | Done | `BuildingPanel` Destroy button → `ConstructionManager.request_destroy` |
| Crystal cost to build; default balance 1,000,000 / player | Done | `src/economy/economy_config.gd` + `GameManager.crystals_for/try_spend_crystals/grant_crystals`, reset each `RUNNER_PREPARATION` |
| Construction is not instant; replicated progress bar | Done | `Building.state` (`UNDER_CONSTRUCTION` / `UPGRADING` / `IDLE`) + `BuildProgressBar` |
| Wall / Tower / Crystal Mine structures, each with an object scene | Done | `src/buildings/wall.tscn`, `tower.tscn`, `crystal_mine.tscn` (one shared `building.gd`, data-driven by `BuildingDef`) |
| Structures have HP and are attackable by the Hunter | Done | `HealthComponent` on `Building`; `Unit._enemy_candidates()` includes `"buildings"` group for the Hunter; `Unit._perform_melee_on_building` |
| Walls (and other structures) physically block unit movement | Done | `Unit` collision mask now includes the `building` layer (`src/units/unit/unit.tscn`) |
| Level system: cost, HP, and build time all increase per level | Done | `BuildingDef.cost_for_level/hp_for_level/build_seconds_for_level` (exponential growth, configurable per type) |
| Crystal Mine generation (`2^(level-1)` crystals / tick) | Done | `BuildingDef.mine_output_for_level`, matches docs/economy.README.md §2.1 table through level 12 |
| Tower acquires and auto-attacks Hunters in range | Done | `Building._tick_tower` (reuses `AttackController`) |
| Headless logic test (levels, costs, economy spend/grant) | Done | `tests/construction/building_economy_test.gd` + `scripts/test/building_economy_test.ps1` |
| Interactive test scene (build UI + grid, no lobby required) | Done | `tests/construction/building_system_test.tscn` |

**Deliberately out of scope (not requested):** Hunter Crystal income from damage dealt (`docs/economy.README.md` §3.1 — WP-03); Hunter Shop; explicit right-click targeting of a building (the Hunter still auto-engages a nearby building via normal combat acquisition); real pathfinding around structures (existing straight-line movement limitation, now more visible once Walls exist).

**Doc owners:** `building.README.md`, `construction.README.md`, `economy.README.md`

The balance rows above (1,000,000 Crystals, `2^(level-1)`) and the "out of scope" Hunter damage income are superseded by CP-16.

---

## CP-16 — Crystal rebalance, Tower projectiles, Wall shield, Runner repair

**Verification:** every item was implemented and checked by code review plus an independent reviewer pass; nothing has run in Godot yet ("Done" here means written and reviewed). A–C landed in `b674c55`, D and the E docs in the following commit. The editor pass is WP-16 E in `working_packages.README.md`.

| Item | Status | Evidence |
| --- | --- | --- |
| Starting Crystals 20; Hunter 0.2 Crystals / applied damage | Done | `src/economy/economy_config.tres`; `GameManager.award_damage_crystals` called from both melee sites in `unit.gd` |
| Costs ×1.8 per level, max levels Mine 11 / Wall 20 / Tower 20, mine 2 → 2048 | Done | `src/buildings/defs/*.tres`, `BuildingDef` |
| Coalesced 4 Hz roster broadcast for income | Done | `GameManager._mark_players_dirty` / `PLAYERS_SYNC_INTERVAL` |
| Crystal HUD top-center for both roles with mine income `+X/s` | Done | `ui/hud/resource_bar/` |
| Build panel restructure (detail line, Max level, tower pick grid) | Done | `ui/hud/building_panel/` |
| Tower stats on `StatSheet`, `ATTACK_RANGE` appended | Done | `Building._setup_tower_stats` / `_rebuild_tower_stats`, `StatBlock.Stat.ATTACK_RANGE` |
| Homing projectile; damage on impact; cosmetic client copy | Done | `src/combat/projectile.{gd,tscn}`, `Building._broadcast_projectile` |
| One of four tower stat picks per upgrade, host-validated, applied on completion | Done | `ConstructionManager._server_upgrade`, `Building.queue_tower_pick` |
| Wall shield from Lv 15 (soak first, delayed recharge), replicated + shield bar | Done | `src/components/shield/shield_component.gd`, `Building.apply_damage`, `building.tscn` |
| Runner `repair` skill: RMB own damaged structure, host-validated | Done | `src/skills/` (`SkillDef`, `repair_def.tres`, `RepairSkill`), `Unit.server_repair_tick` |
| Headless tests | Done (not run) | `tests/combat/tower_projectile_test`, `tests/skills/repair_skill_test`, `tests/construction/building_economy_test` + `scripts/test/*.ps1` |
| Interactive harnesses | Done (not run) | `tests/construction/tower_combat_test.tscn`, `wall_repair_test.tscn`, `building_system_test.tscn` |
| Match integration pass in the editor | Not done | WP-16 E — needs Godot (`godot --headless --import` first) |

**Open balance decisions:** listed under WP-16 "Open decisions for the user" (late-level costs, repair numbers, shield-damage income, crit cap, panel margins).

**Doc owners:** `economy.README.md`, `construction.README.md`, `controls.README.md`, `stats.README.md`, `building.README.md`

---

## CP-17 — HUD overhaul: HudMode, building selection, Runner A-destroy

**Verification:** implemented and checked by code review; nothing has run in Godot yet ("Done" here means written and reviewed), same as CP-16. The editor pass is WP-17 E in `working_packages.README.md`.

| Item | Status | Evidence |
| --- | --- | --- |
| Match HUD corners unchanged (minimap BL, SelectionPanel BC, BuildingPanel BR) | Done | `game/match/hud.tscn` |
| Building panel ~300×360 | Done | `ui/hud/building_panel/building_panel.tscn` (`custom_minimum_size`) |
| `HudMode` UNIT_BUILD / BUILDING_MANAGE mutual exclusion | Done | `src/hud/hud_mode.gd`; `ui/hud/building_panel/building_panel.gd` |
| `BuildingPanel.is_armed` + `"building_ui"` group preserved | Done | `building_panel.gd`; callers in `unit.gd` / `selection_manager.gd` |
| Building selection circle + hover/selected visuals | Done | `src/buildings/building.gd` (`set_selection_hover` / refresh); `SelectionCircle` on building scene |
| Owned buildings resolve as OWN tier | Done | `src/selection/selection_resolver.gd` (`is_own`) |
| SelectionPanel building portrait / kind stats / HP / level | Done | `ui/hud/selection_panel/selection_panel.gd` (`_show_building`) |
| Upgrade / Destroy / tower picks only in BUILDING_MANAGE | Done | `building_panel.gd` + `HudMode.can_manage_building` |
| Destroy → `request_destroy`; `_server_destroy` runs `_can_build` | Done | `src/construction/construction_manager.gd` |
| Destroy clears selection + auto-selects local unit | Done | `Building._exit_tree` → `SelectionManager.notify_entity_removed` |
| Runner A arms with melee 0; A+LMB own building → destroy | Done | `HudMode.can_runner_a_destroy`; `selection_manager.gd` |
| Hunter A-move combat unchanged; Hunter RMB attacks buildings | Done | `unit.gd` `_request_attack_building` |
| Shared `stat_icon_row` + recycled StatIcons / crystal icon | Done | `ui/hud/widgets/stat_icon_row.tscn`; `StatIcons`; `BuildingIcons.crystal_icon` |
| Offline Python / gdparse verification (no Godot) | Done | `tools/test/test_hud_wp17.py` + `hud_mode_rules.py`; helper `tests/hud/hud_layout_preview.tscn` |
| Match / editor verification | Not done | WP-17 E — needs Godot |

**Doc owners:** `controls.README.md`, `selection_panel.README.md`, `construction.README.md`, `ui_audio.README.md`, `project_architecture.README.md`

---

## CP-18 — Hunter structure attack polish + floating numbers

**Verification:** implemented and checked by code review; nothing has run in Godot yet ("Done" here means written and reviewed), same as CP-16 / CP-17. The editor pass is WP-18 D in `working_packages.README.md`. Floating-number checklist detail: WP-09.

| Item | Status | Evidence |
| --- | --- | --- |
| Footprint-aware melee reach / in-range / approach vs buildings | Done | `src/combat/structure_melee.gd` (`StructureMelee`) |
| Attack range checks use StructureMelee for Building targets | Done | `src/combat/attack_controller.gd` (`in_attack_range`) |
| Building click hit floor 56 px; chase / server attack use approach point | Done | `src/units/unit/unit.gd` (`_clickable_enemy_building_at`, chase, `_server_attack_building`) |
| Stuck move clears when already in melee range of acquired building | Done | `unit.gd` stuck-move handling vs acquired target |
| Hunter bot considers buildings as targets | Done | `unit.gd` `_nearest_hunter_target` |
| Red attack flash on structures | Done | `Building.flash_attack_target_circle` |
| Floating combat / regen numbers (white / yellow / green; rise + fade) | Done | `src/fx/floating_number.gd` (`FloatingNumber.spawn` / `spawn_on`; Kind DAMAGE / CRIT / LIFESTEAL / REGEN) |
| Wired from melee (unit + building), lifesteal, regen (≥ 1 batch), tower projectile hit | Done | Call sites in `unit.gd` / combat / building / regen paths |
| Spec updates | Done | `controls.README.md`; WP-09 Done + WP-18 in `working_packages.README.md` |
| Match / editor verification | Not done | WP-18 D — needs Godot |

**Doc owners:** `controls.README.md`, `construction.README.md`, `ui_audio.README.md`, `working_packages.README.md` (WP-09 / WP-18)

---

## CP-19 — Hunter XP and portrait XP ring

**Verification:** implemented and checked by code review; nothing has run in Godot yet. Level-up **stat rewards** remain open (WP-14 still-open).

| Item | Status | Evidence |
| --- | --- | --- |
| Shared XP curve + fill helper | Done | `src/progression/xp_progress.gd` (`XpProgress`) |
| Host-owned level / XP on units, replicated | Done | `Unit.level` / `Unit.xp` + `unit.tscn` MultiplayerSynchronizer |
| Hunter gains XP from applied melee damage (units + buildings) | Done | `Unit.grant_xp` from `_perform_melee_on_unit` / `_perform_melee_on_building` |
| Runners stay level 1 with full violet ring | Done | `Unit.xp_fill_ratio`; selection panel runner path |
| Portrait grey double frame + dark band + violet CCW fill | Done | `ui/hud/selection_panel/portrait_xp_ring.gd` |
| Overlapping level badge beside portrait | Done | `SelectionPanel` LevelBadge |
| Empty selection: grey frame, no fill / badge | Done | `SelectionPanel._show_empty` |
| Sandbox XP+50 (Hunter) | Done | `game/sandbox/sandbox_panel.gd` |
| Spec / offline checks | Done | `docs/selection_panel.README.md`, `docs/stats.README.md`, `tools/test/test_wp14_xp.py` |
| Match / editor verification | Not done | Needs Godot |

**Doc owners:** `selection_panel.README.md`, `stats.README.md`, `working_packages.README.md` (WP-14)

---

## CP-06 — Sandbox, bots, tests

| Item | Status | Evidence |
| --- | --- | --- |
| Debug sandbox panel | Done | `game/sandbox/sandbox_panel.gd` |
| Top-left action bar (compact) + Runner/Hunter sample icons | Done | Host, bots, quick start, continue, skip, reset; headless **on by default** |
| Top-right Tests panel | Done | Open lobby / roles / game alone (clears sandbox action bar) |
| Bottom-right status + scrollable GameLog | Done | Phase, peers, last action; `ScrollContainer` + `GameLog` history listener |
| Host, add bots, quick-start 1H+2R | Done | Sandbox actions |
| Skip preparation / reset / open s0–s2 alone | Done | Reset works online (host) and offline; deferred `force_open` lobby; null-safe unit multiplayer during teardown |
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
| `ui/lobby`, `ui/role_selection`, `ui/styles/`, `ui/widgets/` (+ `ui_kit`), `ui/hud/{health_bar,selection_panel,minimap}` | Active |
| `default_bus_layout.tres` (Master → Music / SFX) | Wired in `project.godot` |
| `tests/{bots,session,stats,navigation,combat}`, `scripts/test/` | Active |
| Web preset in `export_presets.cfg` | Present; export path / CI still open |
| GodotSteam addon | Removed | Networking is ENet-only |
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
| Lobby branded card, ENet-only host/join | Done | `ui/lobby/lobby.tscn` + `.gd` + `ui/styles/` |
| Sandbox chrome non-overlapping layout | Done | Action TL / Tests TR / Status BR; HUD under action bar |
| Camera bound padding (overscroll) | Done | `MatchCamera.bound_padding` default `360` screen px |
| Config documented | Done | `docs/ui_audio.README.md`, `README.md` runtime section, `controls.README.md` §2.2 |

**Doc owners:** `ui_audio.README.md`, `controls.README.md` §2, root `README.md` runtime configuration

---

## CP-14 — Attack UX, shift-click chains, camera, sandbox polish

| Item | Status | Evidence |
| --- | --- | --- |
| Right-click attack on attackable (Hunter) + red entity flash | Done | `unit.gd` + `MoveClickMarker.ATTACK_COLOR` / `flash_attack_target_circle` |
| A then LMB attack-move + red ground marker | Done | `SelectionManager.attack_move_armed` |
| Shift+RMB green move chain (world + minimap) | Done | `issue_chain_append` + `MoveChainVisual.MOVE_COLOR` |
| Shift+A+LMB red attack-move chain (world + minimap); mixable with green | Done | `issue_attack_chain_append` |
| Chain path prioritizes over in-range auto-attack | Done | Active `_move_chain` skips combat acquire |
| Plain RMB / plain A+LMB cancels chain | Done | Clears visual + server waypoint queue |
| Minimap move / chain / attack-move / attack-chain | Done | `ui/hud/minimap/minimap.gd` |
| MMB camera drag; tuned edge-scroll exports | Done | `match_camera.gd` |
| Sandbox Reset + scrollable log | Done | `GameManager.reset_match` deferred lobby; `GameLog` UI buffer |
| Spec updates | Done | `controls.README.md`, `minimap.README.md` |

**Doc owners:** `controls.README.md` §1.2–§1.3 / §2, `minimap.README.md` §2.3

---

## First milestone verdict

Per `docs/instructions.README.md` Definition of Done, the **session + multiplayer technical skeleton is largely complete**. Basic melee combat, attack-move, shift-click move/attack chains, hunter-bot hunting, elimination/observer, free camera (edge-scroll + MMB drag), editor-previewable HUD shells (CP-13), and persistent UI/audio settings are also in.

Still open in `working_packages.README.md`: Hunter Shop, fog of war (minimap FoW), cursors, and SelectionPanel context-action buttons. Grid building foundation is CP-11; UI/audio/settings presentation is CP-12; editor-preview scenes are CP-13; attack/chain UX is CP-14; match-integrated construction + Crystal economy is CP-15; crystal rebalance / tower projectiles / wall shield / repair is CP-16 (editor pass open); HUD overhaul (HudMode, building selection, Runner A-destroy) is CP-17 (editor pass open); Hunter structure melee polish + floating numbers is CP-18 (editor pass open); Hunter XP + portrait ring is CP-19 (level-up rewards still open; editor pass open).
