# Working Packages — Open Topics

Open work remaining relative to `docs/` and the root `README.md`.

Use this file together with `checkpoints.README.md` to compare open topics against what is already implemented and to pick the next milestone.

---

## How to use

1. Read `checkpoints.README.md` for what is already Done / Partial.
2. Pick the next package below (suggested order at the bottom).
3. When a package lands, move its checklist items into checkpoints (or mark them Done here and mirror there).
4. Owning doc is authoritative for behavior details.

| Priority | Meaning |
| --- | --- |
| P0 | Needed for the next playable gameplay loop after the session skeleton |
| P1 | Completes core asymmetric combat / economy / build fantasy |
| P2 | Presentation, polish, and pipeline hardening |

---

## WP-01 — Health, combat, and elimination (P0)

**Owning docs:** `gameplay.README.md` §6, `controls.README.md` §5, `stats.README.md` §2, `project_architecture.README.md` (`src/combat/`, health components)

### Done (see CP-08 / CP-14)

- [x] Unit health component + synced current health
- [x] Right-click attack + chase into `attack_range` (red target flash)
- [x] Acquisition range vs attack range (melee)
- [x] Minimal melee attack path (instant swing, no hitbox scene yet)
- [x] Crit / lifesteal / defense hooks in `CombatDamage` (role defaults currently 0 for clear fights)
- [x] Health regeneration tick (role defaults currently 0)
- [x] Runner / Hunter elimination when health ≤ 0
- [x] Dead Runners become observers (free camera + HUD)
- [x] Enter `Phase.ENDED` and resolve win / loss
- [x] Hunter bot seeks and attacks living Runners
- [x] Melee / health automated test scene
- [x] Attack-move (`A` + left click) with red ground marker
- [x] Plain RMB cancels attack / chain (move has priority over auto-attack while pathing)
- [x] Shift+RMB green move chain + Shift+A+LMB red attack-move chain (mixable; chain outranks in-range auto-attack)

### Still open

- [ ] Hitbox / hurtbox scenes for wind-up / projectile contact
- [ ] Ranged / magic attack execution paths
- [ ] Structure health (needs WP-02 buildings)
- [ ] Tune non-zero crit / lifesteal / regen / defense for playtests

### Depends on

- CP-04 movement (done)
- CP-05 stat calculation (done)

### Blocked by / unlocks

- Unlocks Hunter damage-based crystal income (WP-03)
- Unlocks tower offensive behavior (WP-02)

---

## WP-02 — Construction and structures (P0)

**Owning docs:** `construction.README.md`, `building.README.md`, `gameplay.README.md` §3–§4, `project_architecture.README.md` (`src/buildings/`, `src/construction/`)

### Done (see CP-11 / CP-15)

- [x] Grid-based placement rules documented (`building.README.md`)
- [x] Physics layers: world / obstacle / unit / building / destructible / item
- [x] `BuildGrid` + `PlacementValidator` + footprint hitbox `Building`
- [x] Interactive grid test scene + headless footprint logic test
- [x] Match-integrated placement mode (bottom-right build UI → ghost → place in game)
- [x] Crystal Mine / Wall / Tower scenes (one shared `Building` script, data-driven `BuildingDef`)
- [x] Wall (and every structure) blocks unit movement (`Unit` collision mask)
- [x] Structure health and destruction (`HealthComponent`; Hunter melee also damages buildings)
- [x] Structure upgrades driven by configuration (health / cost / build-time / mine output / tower damage all scale with level via `BuildingDef`)
- [x] Server-authoritative build / upgrade / destroy transactions (`ConstructionManager`)
- [x] Runner can destroy their own structures from the build UI

### Open

- [ ] Navigation path recalculation when walls appear / disappear (still straight-line paths — pre-existing CP-04 limitation, more visible now that Walls exist)

### Depends on

- Economy spend validation — landed together with this package (WP-03 starting-balance subset)
- Health / combat for structure destruction and tower attacks (WP-01) — done

---

## WP-03 — Economy and Hunter shop (P0 / P1)

**Owning docs:** `economy.README.md`, `gameplay.README.md` economy sections, `stats.README.md` (shop applies modifiers)

### Done (Runner side — see CP-15)

- [x] Crystal resource owned by authoritative match / player state (`GameManager.players[].crystals`, host-validated spend/grant)
- [x] Crystal Mine generation interval and `2^(level - 1)` output through level 12
- [x] Configurable mine / wall / tower costs and upgrade costs (`BuildingDef` resources; UI only displays them)
- [x] Runner spending: mine / wall / tower build and upgrades
- [x] Centralized economy config resource (`src/economy/economy_config.gd` + per-structure `BuildingDef`)
- [x] Crystal economy automated tests (`tests/construction/building_economy_test.gd`)

### Done (Hunter damage income — see CP-16 / CP-23)

- [x] Hunter crystals from damage dealt (`hunter_crystals_per_damage` via `GameManager.award_damage_crystals`)

### Open (Hunter side — not requested yet)

- [ ] Hunter passive income from Hunter Shop / base (lower than developed mines)
- [ ] Hunter Shop purchases applying `StatModifier`s

### Depends on

- Stats modifiers already exist (CP-05)
- Damage pipeline (WP-01) for damage income
- Structures (WP-02) for mine generation and build spend — done (CP-15)

---

## WP-04 — Selection, camera, and cursors (P0 / P1)

**Owning docs:** `controls.README.md`, `selection_panel.README.md`, `ui_audio.README.md`

### Done (see CP-09 / CP-10 / CP-12 / CP-14)

- [x] Edge-scrolling camera (normalized diagonals)
- [x] Edge-scroll exports tuned (`camera_speed` 1600, `edge_margin` 48)
- [x] Middle-mouse camera drag pan
- [x] `C` centers camera on controlled character (while alive)
- [x] Observer keeps free camera after death
- [x] Camera overscroll padding (`bound_padding`, zoom-aware) so map corners stay inset
- [x] No edge-scroll while cursor is over blocking UI; no auto-recenter on eliminations
- [x] Left-click selection of clickable entities (hover + selected circles, ownership colors)
- [x] Clear selection on empty world click
- [x] Drag-box multi-candidate selection with priority (own → player figures → NPC; else random)
- [x] Selectable vs controllable: only own control group accepts move/attack commands
- [x] Selection system in `src/selection/` (state + circles)
- [x] Selection Panel HUD: fixed-size strip, combat stats grid, health bar + regen (context actions later)
- [x] `C` always centers on own unit regardless of selection
- [x] Persistent settings dock + Music/SFX buses + playlist (CP-12)
- [x] Blue move / red attack click markers; green/red shift-click chain visuals

### Still open

- [ ] Clickable vs attackable capability separation (groups / components) beyond unit methods
- [ ] Context-sensitive cursors (move / attack / invalid / attack-move)
- [ ] Context Action Panel (build, upgrade, …) without hard-coding every instance
- [ ] Capability-driven actions for structures / shop hooks
- [ ] Team / ownership rules for what actions and info are shown in the panel

### Depends on

- Units / structures existing to select (WP-02 for buildings)
- Economy / construction for upgrade / build actions (WP-02, WP-03)

### Notes

- Match camera: `game/camera/match_camera.gd` (`bound_padding` default 360; MMB drag; edge-scroll exports). HUD: phase status, selection strip, minimap. UI/audio: `docs/ui_audio.README.md`.

---

## WP-05 — Vision, fog of war, and minimap (P1)

**Owning docs:** `gameplay.README.md` §7, `minimap.README.md`, `vision.README.md`

### Done (partial, pre-FoW — see CP-10 / CP-14)

- [x] Live minimap with map asset + unit pixels (own green / runners blue / hunter red)
- [x] Relative world→minimap position mapping
- [x] Minimap color rules documented in `minimap.README.md` §2.1
- [x] Camera frustum outline on minimap
- [x] Minimap LMB recenters camera
- [x] Minimap RMB move / Shift+RMB green chain / A+LMB attack-move / Shift+A+LMB red attack-chain

### Open

- [x] Author `docs/vision.README.md`
- [x] Team vision ranges and fog-of-war state (`RoleConfig.vision_range`, `BuildingDef.vision_range`, shared per team)
- [x] Vision states: Unexplored / Currently Visible / Previously Seen
- [x] Last-known structure information (structures only; units are intentionally never remembered)
- [x] `src/vision/` implementation (`VisionSystem`, `VisionKnowledge`, fog overlay, entity presenter, last-known ghost layer)
- [x] Minimap presentation from known information only (fog, hidden enemy units, last-known structure ghosts)
- [ ] Configurable structure icons on minimap (structures are footprint-colored rects today; no configurable icons)
- [x] Separate Runner vs Hunter knowledge (switching the viewing team discards the old team's knowledge)
- [x] Moving units do not leak live positions outside vision
- [x] Vision test coverage: `tests/vision/vision_test.tscn` (headless; runner `scripts/test/vision_test.ps1`). Covers the `VisionSystem` API that the minimap and ghost layer draw from. Minimap pixel drawing itself is not asserted. **Not yet executed in Godot** (no Godot binary available when written)

### Depends on

- World entities and structures (WP-02)
- Selection / HUD shell useful but not strictly required first

---

## WP-06 — Sandbox and bot depth (P1)

**Owning docs:** `project_architecture.README.md` §8–§9, `instructions.README.md` §4

### Done

- [x] Sandbox action bar: host / bots / quick-start / continue / skip prep / reset
- [x] Skip runner preparation (host)
- [x] Reset match to lobby (host + offline; deferred scene open; null-safe multiplayer teardown)
- [x] Bottom-right scrollable GameLog panel
- [x] Open lobby / role selection / game scenes alone (Tests panel)
- [x] Bot client connect / vote / spawn / move; Hunter bot chase+attack

### Open

- [ ] Spawn units and structures from sandbox
- [ ] Modify crystals and stats at runtime
- [ ] Apply damage / healing; destroy selected entities
- [ ] Change structure levels at runtime
- [ ] Toggle fog of war / reveal map / test vision ranges
- [ ] Bot build behaviors for multiplayer coverage
- [ ] Component / combat / shop / building test scenes listed in architecture

### Depends on

- Features under test from WP-01 … WP-05

---

## WP-07 — Repository layout and cleanup (P2)

**Owning docs:** `project_architecture.README.md` §3–§5

### Done

- [x] `src/` folders landed with features: `components/health`, `buildings`, `combat`, `construction`, `selection` (+ `fx`, `logging`, `navigation`, `stats`, `units`, `match`)
- [x] HUD folders under `ui/hud/`: `selection_panel`, `minimap`, `health_bar`
- [x] Dedicated camera module: `game/camera/match_camera.gd`
- [x] GodotSteam / unused Steam paths removed (ENet-only)

### Open

- [ ] Create remaining `src/` folders as features land: `economy`, `inventory`, `items`, `vision`
- [ ] HUD folders still missing: `resources`, `stats` (if needed beyond selection panel)
- [ ] Real `game/arena/` (optional split from current match/maps layout)
- [ ] Remove or document empty legacy shells (`components/`, `common/`, `data/`, `entities/`, `game/player/`) if any remain
- [ ] Drop unused WASD / attack input map leftovers if mouse-only controls stay the standard
- [ ] Keep scenes + primary scripts co-located per feature (ongoing)

---

## WP-08 — Build, export, and CI pipeline (P2)

**Owning docs:** `project_architecture.README.md` §10–§11

### Open

- [ ] Pin / verify Godot 4.7.2 stable consistently in CI docs or scripts
- [ ] `scripts/export/export.sh` (or Windows-equivalent) for automated export
- [ ] Fill Web export path in `export_presets.cfg`; produce `build/web/`
- [ ] CI: checkout → verify Godot → import → validate → unit tests → multiplayer smoke → web export → artifacts
- [ ] Keep generated builds out of source control

### Notes

- Local PowerShell test runners already exist under `scripts/test/`.

---

## WP-09 — Floating hit / heal number indicators (P1)

**Owning docs:** `controls.README.md` (feedback), `ui_audio.README.md`, `stats.README.md` (damage / crit / lifesteal / regen)

Combat and regen feedback as rising world-space numbers that spawn near the entity whose health changed. Landed with CP-18 / WP-18 (code-reviewed; editor open).

### Done (see CP-18)

- [x] Shared FX class `FloatingNumber` (`src/fx/floating_number.gd`) — MoveClickMarker-style API (`spawn` / `spawn_on`), not an autoload
- [x] Spawn at a **random offset around the affected entity** (damage on the target that was hit; lifesteal / regen on the unit that gained HP)
- [x] Numbers rise upward and fade out after spawn
- [x] Color map:
  - normal hit damage → **white** (`Kind.DAMAGE`)
  - crit hit damage → **yellow** (`Kind.CRIT`)
  - lifesteal amount → **green** (`Kind.LIFESTEAL`)
  - HP regen tick → **green** (`Kind.REGEN`; batched when gained ≥ 1)
- [x] Wired into melee resolve (unit + building), lifesteal, regen, and tower projectile impact
- [x] Local-only presentation (same pattern as `MoveClickMarker`) without breaking multiplayer sync

### Open

- (none for the scoped checklist — further polish / DOT sources can reuse `FloatingNumber.spawn`)

### Depends on

- Existing melee + regen pipeline (WP-01 / CP-08); building melee polish (WP-18)

### Notes

- Chosen default: one `FloatingNumber.spawn(parent, world_pos, value, kind)` / `spawn_on(node, …)` entry point (mirrors `MoveClickMarker`), not a separate autoload factory.

---

## WP-10 — In-game chat (P1)

**Owning docs:** `ui_audio.README.md`, `project_architecture.README.md` (HUD / networking)

### Open

- [ ] Match HUD chat panel (send + receive)
- [ ] Host-authoritative (or reliable RPC) message broadcast to all peers
- [ ] Enter / Esc focus rules so chat typing does not steal move / camera / attack input
- [ ] Optional: team vs all channel (Runner team / Hunter / everyone)
- [ ] Persist a short scrollable history for the current match only
- [ ] Basic mute / filter hooks (placeholder OK)

### Depends on

- Existing ENet session + match HUD shell (CP-02 / CP-10 / CP-13)

---

## WP-11 — Hunter animated weapon on hit (P1)

**Owning docs:** `gameplay.README.md`, unit presentation / combat feedback

### Open

- [ ] Hunter weapon (or swing) visual attached to the Hunter unit
- [ ] Play a short attack animation when a melee swing connects (or when the swing starts — pick one and document it)
- [ ] Animation does not change damage timing / server authority (cosmetic only unless later synced)
- [ ] Placeholder art OK; keep sprite / AnimationPlayer (or AnimatedSprite) co-located with Hunter scene
- [ ] Optional: subtle impact FX on the target when the hit lands

### Depends on

- Melee swing path (WP-01); benefits from hit indicators (WP-09) for combined feedback

---

## WP-12 — DRY / redundancy cleanup without behavior changes (P2)

**Owning docs:** `project_architecture.README.md`, `instructions.README.md` (keep gameplay logic outside UI)

Audit and refactor duplicated code so the game **behaves identically** after cleanup.

### Open

- [ ] Inventory of redundant paths (duplicated clamp / marker host / selection lookup / multiplayer-ready guards / command issue helpers)
- [ ] Extract shared helpers only where call sites stay behavior-identical
- [ ] Deduplicate minimap vs world command issuance (move / chain / attack-move) behind one unit API where safe
- [ ] Review combat tick / chain resume / attack-move resume for repeated “resume path” patterns
- [ ] Review sandbox / GameLog / scene transition reset paths for duplicated lobby reset logic
- [ ] No intentional gameplay changes; verify with existing headless tests + manual smoke (move, attack, chain, minimap, reset)
- [ ] Document any extracted helpers in architecture notes if they become shared modules

### Depends on

- Stable CP-14 control/combat UX (do not refactor mid-feature)

### Notes

- Goal is DRY and clarity, **not** rewrites. Prefer small extractions over large redesigns.

---

## WP-13 — World health bar, name, and level rhombus (P1)

**Owning docs:** `selection_panel.README.md` (world vs HUD), `ui_audio.README.md`, unit presentation

Over-unit HUD chrome for living players.

### Open

- [ ] Make the world-space health bar **larger** than the current thin bar
- [ ] **Center** the health bar horizontally over the player sprite
- [ ] **Center** the player name label over the player (aligned with the bar / sprite)
- [ ] Place a **rhombus (diamond)** immediately to the **left** of the health bar showing the **player level**
- [ ] Health bar **vertical tick lines**: one thin vertical line per HP of max health (e.g. 1000 max HP → 1000 thin lines across the bar). If that is too dense for performance/readability, fall back to a tick every 100 HP and document the choice
- [ ] Keep offsets stable across Runner / Hunter sprite sizes (or derive from sprite bounds)
- [ ] Preserve existing health sync / elimination behavior (presentation-only unless layout requires minor node tweaks)

### Depends on

- Existing `HealthBar` + unit `NameLabel` (CP-03 / CP-08)
- Player level state (WP-14) for the rhombus number

---

## WP-14 — Player XP and levels (P1)

**Owning docs:** `stats.README.md`, `gameplay.README.md`, `selection_panel.README.md`

Per-player experience and leveling with selection-panel feedback.

### Done (see CP-19; presentation polish also CP-10 / CP-20)

- [x] Authoritative unit **level** + **XP** (`Unit.level` / `Unit.xp`, MultiplayerSynchronizer)
- [x] XP curve via `XpProgress` (`BASE_XP * GROWTH^(level-1)`; each level costs more)
- [x] Grant XP: Hunter melee damage dealt (units + buildings), 1 XP per applied damage
- [x] Selection panel: matching-thickness grey double frame + dark band; violet fill counterclockwise from 12 o'clock; overlapping level badge
- [x] Stats column spaced right of portrait; **no** “Lv N” beside the health bar (badge only)
- [x] Runners fixed at level 1 with full violet ring; buildings show structure level, empty XP band
- [x] Empty selection: grey frame only (no fill / badge)
- [x] Sandbox **XP +50** button (Hunter only)
- [x] Docs + offline `tools/test/test_wp14_xp.py`

### Still open

- [ ] Level-up applies agreed rewards (document first: e.g. stat bumps via `StatModifier`, or none until tuned)
- [ ] Match / editor verification in Godot

### Depends on

- Selection panel portrait ring (CP-10); stats modifiers (CP-05) if level-ups grant stats

### Notes

- Prefer a small `XpProgress` / level helper (curve + fill 0–1) so HUD and future widgets stay DRY.
- World-space level rhombus beside the health bar is tracked under WP-13.

---

## WP-15 — Skins, shaders, and movement animations (P1)

**Owning docs:** `gameplay.README.md`, unit presentation, `ui_audio.README.md` (optional SFX hooks)

Player visual customization and locomotion polish.

### Open

- [ ] Skin system for Runner / Hunter (swap textures / materials / palette without breaking selection / minimap / combat)
- [ ] Shader-based skin variants (e.g. outline, tint, glow, team accent) driven by skin config resources
- [ ] Movement animations: idle / walk (and optional run) driven by velocity / move orders
- [ ] Animation does not change server movement authority (cosmetic / client presentation; sync only if needed later)
- [ ] Keep skin + animation assets co-located with unit scenes; document how to add a new skin
- [ ] Selection circle, health bar, name, and level rhombus stay correctly aligned when skins / anims change bounds

### Depends on

- Shared Unit / Runner / Hunter scenes (CP-03 / CP-04)
- Benefits from WP-13 layout once world chrome is resized/centered

---

## WP-16 — Crystal economy rebalance, Tower projectiles, Wall shield, Runner repair (P0 / P1)

**Owning docs:** `economy.README.md`, `construction.README.md`, `building.README.md`, `controls.README.md`, `stats.README.md`

Follow-up to CP-15, which shipped construction with placeholder balance (1,000,000 starting Crystals) and no Hunter income, no real tower attack, and no Wall mechanic beyond HP. Started 2026-11-26.

> **Verification status: nothing in this package has been executed.** Godot is not installed on the dev machine by choice, so every item below was implemented and checked **by code review only**. A `[x]` means "written and reviewed", *not* "ran green". The whole package needs one pass in the editor before it can be called done.

### How to pick this package up

Everything needed to continue is in this section plus the files it names — no external plan document is required.

**Environment:** Godot is **not installed on the dev machine, by choice — do not install it.** Verify by reading code. Nobody can compile-check, so be exact with GDScript syntax, Godot 4 API names, and `.tscn` / `.tres` format. Work one package at a time: one agent implements, a **second, independent agent reviews** before the next package starts (A and B were done this way; it caught three defects that would each have detonated later).

**Hard invariants — breaking any of these is silent, not loud:**

- `Building` with `def == null` is a supported legacy path (`tests/construction/building_grid_test.tscn` places footprint-only buildings with no health / stats / economy). Nothing may assume `def != null`.
- `StatBlock.Stat` is **append-only**. Inserting a value silently rewrites every serialized `.tres`.
- `load_steps` in a `[gd_scene]` header must equal `[ext_resource]` + `[sub_resource]` count **+ 1**.
- Any node a script reaches via `%Name` needs `unique_name_in_owner = true`, or `@onready` resolves to null at runtime.
- `BuildingPanel.is_armed()` and the `"building_ui"` group are called by `unit.gd` and `selection_manager.gd` — that contract must not change.
- `HealthComponent.setup(0.0)` yields `_alive = false` **without** emitting `died` → an invulnerable, un-targetable, never-removed entity. Never feed a possibly-zero max health into it.
- Host-authoritative throughout: gate state changes on `multiplayer.is_server()`; clients send intent via RPC. Offline play uses `OfflineMultiplayerPeer`, where the local peer *counts as* the server.
- UI presents state and forwards intent only. Gameplay rules live in managers; balance lives in `.tres` (root `README.md`, "Implementation Principle").

**Reuse instead of rewriting:** `HealthComponent` · `StatSheet` / `StatModifier` / `StatIcons` · `AttackController` · `CombatDamage` · `MoveClickMarker` (local-only click feedback) · `BuildGrid` / `PlacementValidator` · the request → RPC → `_server_*` pattern in `ConstructionManager` · the `_check` / `_near` + `print("PASS: …")` + `get_tree().quit(code)` convention in `tests/construction/building_economy_test.gd` and its `scripts/test/*.ps1` runner.

**Balance source of truth:** section A below, the three `src/buildings/defs/*.tres`, `src/economy/economy_config.tres` and `src/skills/defs/repair_def.tres`. The `docs/` files were brought up to date in E; if they ever disagree with the resources, the resources win.

### A — Economy and data foundation — landed, reviewed

- [x] `starting_crystals = 20`, new `hunter_crystals_per_damage = 0.2` (`src/economy/economy_config.*`)
- [x] Costs Lv1 Mine 16 / Wall 8 / Tower 24, growth ×1.8; max level Mine 11, Wall 20, Tower 20
- [x] Mine output `2 * 2^(level-1)`, 2 → 2048, capped at Lv 11
- [x] Wall shield data: unlock Lv 15, base / growth / recharge delay / recharge rate
- [x] Tower stat-path data + `BuildingDef.TowerPath` enum + `tower_base_stats` StatBlock
- [x] `max_build_seconds` cap (only binds for the Tower, from Lv 17)
- [x] `StatBlock.Stat.ATTACK_RANGE` appended (never inserted) + `StatIcons` mapping
- [x] `CombatDamage.resolve_ranged()` next to an unchanged `resolve_melee()`
- [x] `GameManager.award_damage_crystals()` + coalesced 4 Hz roster broadcast (mine ticks and Hunter hits no longer fire a reliable full-roster RPC each time)
- [x] Headless assertions updated to the new numbers (`tests/construction/building_economy_test.gd`)

### B — Crystal HUD and build-panel restructure — landed, reviewed

- [x] `ui/hud/resource_bar/` top-center, visible to **both** roles, with `+X/s` mine income
- [x] `BuildingIcons.crystal_icon()` (runtime-drawn, no art dependency, headless-safe)
- [x] Build panel 260×224 → 300×340: `CrystalsLabel` removed, per-structure detail line, "Max level" state, 2×2 tower pick grid staged
- [x] Interactive harness `tests/construction/building_system_test.tscn` shows the bar without the lobby flow
- [x] Income readout counts a mine that is mid-upgrade (it keeps producing in `State.UPGRADING`)

### C — Tower stats, projectiles, upgrade picks — landed, reviewed

- [x] Tower migrated onto `StatSheet` / `CombatDamage.resolve_ranged`
- [x] `src/combat/projectile.{gd,tscn}` using `assets/sprites/items/projectiles/projectile_lvl1.png`
- [x] Replicated `tower_picks`, one of 4 paths per upgrade, host-validated in `ConstructionManager`
- [x] Four pick buttons wired in the build panel
- [x] Headless `tests/combat/tower_projectile_test.*` + `scripts/test/tower_projectile_test.ps1`
- [x] **Independent feature review of C** — no blockers. Fixed from it:
  - a pick is now *queued* (`Building.queue_tower_pick`) and applied in `_complete_construction()` together with the level and HP, instead of instantly at upgrade start (which also let a tower hold more picks than levels mid-upgrade)
  - `_server_upgrade` now runs `_can_build()` (role / eliminated / phase), like `_server_build` — previously an eliminated Runner or a peer in `Phase.ENDED` could still buy upgrades
  - test: the "another peer cannot upgrade" check could never fail (it asserted the owner's balance; peer 2 is not in the roster) — now asserts state / pending pick / level
  - test: tower balance pinned as literals (18 dmg, 1.0 atk/s, 280 range, ×1.5 crit, pick increments, 650 px/s), plus one end-to-end `_tick_tower` → projectile → Hunter HP check
  - `push_warning` when a tower def has no `tower_base_stats` (it would silently never fire)
  - build panel shows "Upgrading to Lv N…" instead of the stale cost line while an upgrade runs
- [x] Interactive `tests/construction/tower_combat_test.tscn` — it did exist (the earlier "dropped" note was wrong); reviewed as usable. Pick buttons now disable during an upgrade; patrol widened to 1100 px so the dummy still leaves range after many Range picks

### D — Wall shield and Runner `repair` skill — landed, reviewed

- [x] `src/components/shield/shield_component.gd` (mirrors `HealthComponent`'s shape, but has no alive / `died` state — a max of 0.0 is the normal "no shield" value, so the `setup(0.0)` trap does not exist here)
- [x] `Building.apply_damage()` as the single structure damage entry point: shield first, then health, returns applied (shield + health). The Hunter melee site in `unit.gd` is the only caller; nothing else writes structure HP directly
- [x] Replicate `sync_current_shield` / `max_shield`; `ShieldBar` (instance of `health_bar.tscn`, blue fill override) above the health bar in `building.tscn`, hidden while `max_shield == 0`
- [x] **Hunter Crystal income wired** at both melee sites in `unit.gd` (vs Runners *and* vs structures), paid on applied damage
- [x] `src/skills/skill_def.gd` + `src/skills/defs/repair_def.tres`; rules in `src/skills/repair_skill.gd` (`RepairSkill.can_repair` / `in_range` / `approach_point`), shared by the click, the RPC and the tests
- [x] Runner RMB on an own finished, damaged structure → walk into range, heal `value_per_second`; green `MoveClickMarker.REPAIR_COLOR`. RMB precedence: enemy → repairable own structure → ground move. Every other command (move, chain, attack, attack-move, death, phase lock) cancels the channel; it also ends by itself at full HP
- [x] Host validation: Runner role, owner match, alive, damaged, not `UNDER_CONSTRUCTION` (upgrading structures *can* be repaired)
- [x] Interactive `tests/construction/wall_repair_test.tscn` (Lv 1 + Lv 15 wall, damage button, repairing Runner)
- [x] Headless `tests/skills/repair_skill_test.*` + `scripts/test/repair_skill_test.ps1`
- [x] **Independent feature review of D** — no blockers. Fixed from it:
  - RMB precedence: a nearby Hunter swallowed the Runner's repair click (Runners cannot attack, so "enemy beats structure" now only applies to a unit that can attack)
  - harness: the damage button killed the Lv 1 wall in one press — now 20 % of each wall's HP + shield; destroyed walls are pruned by index (no freed instance in a typed loop)
  - `is_damaged()` ignores float residue (`DAMAGED_EPSILON`) so a visibly full wall after a level-up is not "damaged"
  - a host-rejected repair now falls back to a move toward the structure instead of silently keeping the previous order
  - repair re-aims every 0.5 s while out of reach, order or not (a straight-line order blocked by another structure never finishes)
  - Crystal income is guarded by the Hunter role at both call sites
- [ ] **First run needs an import:** there is no `.godot/` cache, so `ShieldComponent` / `SkillDef` / `RepairSkill` are not in the global class cache yet. Run `godot --headless --import` (or open the editor once) before the `scripts/test/*.ps1` runners
- [ ] Known, pre-existing: on clients `Building._ready()` runs `_begin_construction(1)` and resets level / state / health / shield for one frame until the next sync (replication mode ALWAYS re-sends them). Harmless flicker; skip it on clients if it ever shows

### E — Match integration and documentation — docs done, **editor run open**

Static checks already done without Godot (2026-11-26): all `.gd` files parse with `gdtoolkit`'s `gdparse`; a scene/resource validator found no `load_steps` / id / path / `%Name` problem in any WP-16 file; a Python port of the shield / repair / cost / pick logic, fed from the real `.tres`, reproduces every numeric expectation of the headless tests. None of this replaces running Godot.

- [ ] Confirm the restructured HUD in the real match flow (sandbox quick-start 1 Hunter + 2 Runners, skip prep)
- [ ] Run every `scripts/test/*.ps1` runner + `smoke_test.ps1`
- [x] `economy.README.md` — de-duplicated (§1–§5 appeared twice); mine table 2 → 2048 (Lv 1–11), starting Crystals 20, cost table, `hunter_crystals_per_damage = 0.2`, shield / tower-pick summary. Section numbers kept, so the code's §2.1 / §3.1 / §5 citations still resolve
- [x] `construction.README.md` — tower projectile + upgrade paths (§5), wall shield (§4), `apply_damage` + repair (§6, §6.2; voluntary destroy §6.1 added in WP-17)
- [x] `controls.README.md` — RMB on own structure = repair (§1.2)
- [x] `stats.README.md` — `attack_speed` / `ATTACK_RANGE` rows, append-only rule, towers consume `StatSheet`
- [x] `building.README.md` — shield + projectile notes (§6)
- [x] `tasks/checkpoints.README.md` — CP-16 changelog row + section; CP-15's balance marked superseded

### Open decisions for the user — not bugs, judgement calls

- [ ] **Late-level costs are unreachable by construction.** ×1.8 over 20 levels puts Wall Lv 20 at ~566k and Tower Lv 20 at ~1.7M Crystals; cumulative ~1.27M / ~3.82M. A maxed mine pays 1024/s and mine output caps at Lv 11 while costs keep compounding, so levels past ~15 cannot be reached in a realistic match. Faithful to the confirmed ×1.8 decision — change `cost_growth` in the three `.tres` if that is not the intent.
- [ ] **Build panel vertical margin is ~2px** in the worst case (Tower below max level selected *while* a structure is armed): ~322px of content in 324px. Inside the reviewer's font-metric error bar. Fix = panel height 340 → 364 plus the two instance offsets in `hud.tscn` and `building_system_test.tscn`.
- [ ] **Build-button row overflows horizontally** (~418px of buttons in 280px) because of the 48px icon + `"Crystal Mine"`. Pre-existing, not a WP-16 regression.
- [ ] **`StatBlock.attack_range` duplicates `RoleConfig.attack_range`.** Units report `ATTACK_RANGE = 0.0` through their sheet while `RoleConfig` holds the real 70.0 / 64.0. Harmless today (the selection panel's stat grid is fixed and does not show it), a trap once anything enumerates it.
- [ ] **`ATTACK_RANGE` and `RANGED_DAMAGE` render the same icon.** `assets/sprites/stats/attack_range2.png` exists if a distinct one is wanted.
- [ ] **Hunter melee vs structures bypasses `CombatDamage`** (pre-existing since CP-15): `_perform_melee_on_building` rolls crit inline and structures have no defense. Harmless today; route it through `CombatDamage` if structures ever get defense.
- [ ] **Repair numbers are placeholders chosen in D, not confirmed.** `repair_def.tres`: `value_per_second = 20`, `cast_range = 48` px beyond the structure's hit radius. For scale: a Lv 1 wall (250 HP) refills in ~12 s, a Lv 15 wall (~2.5k HP) in ~2 min. Repair is free (no Crystal cost), stacks across several Runners, and restores HP only — the shield recharges on its own.
- [ ] **Hunter income counts shield damage — and that is farmable.** `apply_damage()` returns shield + health, and the 0.2 Crystals/damage is paid on that total; Hunter lifesteal also triggers on shield hits. A Lv 15 shield refills for free (45/s after 6 s), so a Hunter can earn ~180 Crystals per drain cycle without ever threatening the wall; repaired HP can be farmed the same way. If hitting a shield should pay less (or nothing), change it at the `award_damage_crystals` call in `_perform_melee_on_building`.

### Depends on

- CP-15 construction + economy scaffold (done)
- Stats modifiers (CP-05) for the tower paths and any future skill effects

---

## WP-17 — HUD overhaul: HudMode, building selection, Runner A-destroy (P1)

**Owning docs:** `controls.README.md`, `selection_panel.README.md`, `construction.README.md`, `ui_audio.README.md`, `project_architecture.README.md`

Follow-up to CP-15 / CP-16: keep the three-corner match HUD layout, gate build vs manage UI through a shared `HudMode`, give structures selection chrome and SelectionPanel info, and let Runners A-click destroy their own buildings. Started 2026-11-26.

> **Verification status: code-reviewed only — not run in Godot.** Godot is not installed on the dev machine by choice. A `[x]` means "written and reviewed", *not* "ran green". Package E (editor / match smoke) stays open.

### How to pick this package up

Everything needed is in this section plus the files it names — no external plan document is required.

**Environment:** Godot is **not installed on the dev machine, by choice — do not install it.** Verify by reading code. Be exact with GDScript syntax, Godot 4 API names, and `.tscn` / `.tres` format.

**Hard invariants — breaking any of these is silent, not loud:**

- `HudMode` mutual exclusion: build placement buttons only in `UNIT_BUILD`; Upgrade / Destroy / tower picks only in `BUILDING_MANAGE`. Never show both at once.
- `BuildingPanel.is_armed()` and the `"building_ui"` group are called by `unit.gd` and `selection_manager.gd` — that contract must not change.
- `Building` with `def == null` is a supported legacy path (`tests/construction/building_grid_test.tscn` places footprint-only buildings). Nothing may assume `def != null` (HudMode / SelectionPanel treat those as non-manageable / generic).
- Do **not** install Godot to "verify". Static review and evidence paths only until an editor pass is explicitly requested.

**Reuse instead of rewriting:** `StatIcons` · `BuildingIcons` (incl. `crystal_icon()`) · `SelectionCircle` · `SelectionResolver` · `ConstructionManager.request_destroy` / `_server_*` · `ui/hud/widgets/stat_icon_row.tscn` for shared icon+label rows.

### A — Chrome and building selection visuals — landed, reviewed

- [x] Layout stays: minimap bottom-left, SelectionPanel bottom-center, BuildingPanel bottom-right (`game/match/hud.tscn`)
- [x] Building panel size ~300×360 (`ui/hud/building_panel/building_panel.tscn`)
- [x] Building has `SelectionCircle` + `set_selection_hover` / selected / `refresh_selection_visual`
- [x] `SelectionResolver` treats `is_own(local)` as OWN tier (owned structures compete with own unit for priority)
- [x] SelectionPanel building view: portrait via `BuildingIcons`, HP bar, kind-specific stats with `StatIcons` / `BuildingIcons.crystal_icon`, level
- [x] Shared widget `ui/hud/widgets/stat_icon_row.tscn` for wall/mine upgrade rows and building detail lines
- [x] Stat icons recycled on wall/mine upgrade button captions and building detail rows

### B — HudMode gating — landed, reviewed

- [x] `src/hud/hud_mode.gd`: `UNIT_BUILD` only when local controllable unit selected; `BUILDING_MANAGE` only when owned `Building` selected (`def != null`)
- [x] BuildingPanel wires mode via `HudMode.resolve` — placement arming only in `UNIT_BUILD`; Upgrade / Destroy / tower picks only in `BUILDING_MANAGE`
- [x] Mutual exclusion enforced in panel refresh (build buttons vs manage actions never both live)

### C — Destroy + Runner A-click — landed, reviewed

- [x] BuildingPanel Destroy → `ConstructionManager.request_destroy`
- [x] `_server_destroy` also runs `_can_build` (role / eliminated / phase), like build / upgrade
- [x] `Building._exit_tree` → `SelectionManager.notify_entity_removed` → clear selection + auto-select local unit
- [x] Runner `A` arms even with melee 0; `A`+LMB on own building → `request_destroy` (not combat) via `HudMode.can_runner_a_destroy`
- [x] Hunter A-move combat unchanged; Hunter RMB can target buildings via `_request_attack_building`

### D — Documentation — landed

- [x] `tasks/working_packages.README.md` — this WP-17 section; Milestone C mentions WP-17
- [x] `tasks/checkpoints.README.md` — CP-17 changelog + evidence table
- [x] `docs/controls.README.md` — Runner A-destroy, building selection circles / OWN tier, Hunter RMB on structures
- [x] `docs/selection_panel.README.md` — building view; upgrades/destroy stay on BuildingPanel
- [x] `docs/construction.README.md` — build UI gating + Runner A-destroy path
- [x] `docs/ui_audio.README.md` / `docs/project_architecture.README.md` — panel size, HudMode, `stat_icon_row`, ui_kit note

### E — Verify without Godot — editor run open

- [x] Static / code review of A–C (HudMode mutual exclusion, destroy path, selection chrome, panel wiring)
- [x] Offline Python mirror + structural checks: `python tools/test/test_hud_wp17.py` (HudMode rules, hud.tscn anchors, `%Name` wiring, icon assets, helper scenes)
- [x] `gdparse` on touched `.gd` files; independent DRY review (SelectionPanel icon leak fix, `StatIcons.short_number`, `BuildingIcons.icon_for_def`)
- [x] Helper scenes: `tests/hud/hud_layout_preview.tscn`; `ui_kit` instances BuildingPanel + `stat_icon_row`
- [ ] Confirm match HUD in the editor (sandbox quick-start, select unit → build buttons; select own building → Upgrade/Destroy; A+LMB destroy; Hunter RMB on structure)
- [ ] Run relevant `scripts/test/*.ps1` runners once Godot is available elsewhere

### Depends on

- CP-15 match-integrated construction + build UI (done)
- CP-16 crystal HUD / build-panel restructure / tower picks / repair (done; editor pass still open)

---

## WP-18 — Hunter structure melee polish + floating numbers (P1)

**Owning docs:** `controls.README.md`, `construction.README.md`, `ui_audio.README.md` (FX note), WP-09 checklist

Follow-up to CP-15 / CP-17: make Hunter melee vs buildings footprint-aware (stand at the edge, not the solid center), and ship world-space floating combat numbers (WP-09). Started 2026-11-26.

> **Verification status: code-reviewed only — not run in Godot.** Godot is not installed on the dev machine by choice. A `[x]` means "written and reviewed", *not* "ran green". Editor / match smoke stays open.

### How to pick this package up

Everything needed is in this section plus the files it names. Floating-number checklist detail lives under **WP-09** above.

**Environment:** Godot is **not installed on the dev machine, by choice — do not install it.** Verify by reading code.

**Reuse:** `MoveClickMarker`-style local FX (`FloatingNumber.spawn` / `spawn_on`) · `RepairSkill.approach_point` pattern · `AttackController` · `Building.selection_hit_radius` / `apply_damage`.

### A — Hunter structure melee polish — landed, reviewed

- [x] `StructureMelee` (`src/combat/structure_melee.gd`): footprint-aware `reach` / `in_range` / `approach_point`
- [x] `AttackController.in_attack_range` uses `StructureMelee` for `Building` targets
- [x] `_clickable_enemy_building_at` hit floor 56 px; chase / `_server_attack_building` use approach point
- [x] Stuck-move clears when already in melee range of the acquired building target
- [x] Hunter bot `_nearest_hunter_target` includes buildings
- [x] `Building.flash_attack_target_circle` for red attack feedback on structures

### B — Floating numbers (WP-09) — landed, reviewed

- [x] `FloatingNumber` Kind DAMAGE / CRIT / LIFESTEAL / REGEN → white / yellow / green; rise + fade
- [x] Wired from melee (unit + building), lifesteal, regen (batched ≥ 1), tower projectile hit
- [x] Checklist + notes: see **WP-09** (MoveClickMarker-style API was the chosen default)

### C — Documentation — landed

- [x] `tasks/working_packages.README.md` — WP-09 Done; this WP-18 section; milestones
- [x] `tasks/checkpoints.README.md` — CP-18 changelog + evidence
- [x] `docs/controls.README.md` — footprint approach vs structures; floating combat numbers
- [x] One-liners in `construction.README.md` / `ui_audio.README.md` where helpful

### D — Verify without Godot — editor run open

- [x] Static / code review of A–B
- [ ] Confirm in the editor: Hunter RMB / A-move vs Wall / Tower / Mine (approach edge, flash, damage numbers); floating white/yellow/green on melee / crit / lifesteal / regen / tower hit
- [ ] Run relevant `scripts/test/*.ps1` runners once Godot is available elsewhere

### Depends on

- CP-15 / CP-16 structure combat + repair approach pattern (done)
- CP-17 Hunter RMB `_request_attack_building` (done; editor pass still open)
- WP-09 floating-number scope (checklist Done above)

---

## Suggested next milestones

Compare against `checkpoints.README.md` (first milestone = session skeleton ≈ done).

```text
Milestone A — Fight and finish
  WP-01 core melee / elimination / hunter bot / attack-move / chains  ✅ landed (CP-08 / CP-14)
  Remaining: hitboxes, ranged/magic, combat tuning
  WP-09 floating hit / heal numbers ✅ landed (CP-18; MoveClickMarker-style FloatingNumber)
  WP-18 ◀ Hunter structure melee polish + floating numbers ✅ A/B (code-reviewed);
         docs ✅ C; editor / match run ❌ D. Nothing run in Godot yet.
  WP-11 Hunter animated weapon on hit
  WP-13 Bigger centered world health bar + name + level rhombus + HP tick lines
  WP-15 Skins / shaders / movement animations

Milestone B — Build and earn
  WP-02 Construction: grid foundation ✅ (CP-11); match-integrated build UI + Wall / Tower / Crystal Mine ✅ (CP-15)
  WP-03 Economy: Runner mine ticks + spend ✅ (CP-15); hunter damage income ✅ (WP-16 D / CP-23); Hunter Shop still open
  CP-23 — Hunter Seek + build hotkeys W/T/C/D + type multi-select + one mine ✅ (code-reviewed; offline Python)
  WP-16 — economy rebalance + crystal HUD ✅ A/B; tower projectiles ✅ C (reviewed);
         wall shield + runner repair + hunter damage income ✅ D (reviewed);
         docs ✅ E; editor / match run ❌ E. Nothing run in Godot yet.
  WP-14 Player XP / levels + violet portrait XP ring

Milestone C — Command and HUD
  WP-04 World selection ✅ (CP-09); selection strip ✅ (CP-10); camera drag / edge-scroll ✅ (CP-14)
  WP-17 — HUD overhaul — HudMode + building selection + Runner A-destroy ✅ A–C (code-reviewed);
         docs ✅ D; editor / match run ❌ E. Nothing run in Godot yet.
  Remaining: cursors / SelectionPanel context-action buttons (upgrades/destroy stay on BuildingPanel for now)
  WP-10 In-game chat
  Hunter Shop as an extension of B

Milestone D — Fog and map awareness
  WP-05 Vision doc + FoW + last-known structures + fogged minimap ✅ (headless `vision_test` written, not yet run);
         configurable minimap structure icons still open; sandbox FoW toggle is WP-06
         live minimap + command clicks ✅ (CP-10 / CP-14)

Milestone E — Hardening
  WP-06 Sandbox basics / reset / log / hunter bot ✅; deeper tools still open
  WP-07 Layout cleanup (partial)
  WP-08 CI / export
  WP-12 DRY / redundancy cleanup (no behavior changes)
```

---

## Explicitly out of initial scope (keep parked)

From `project_architecture.README.md` §7.4 — do not pull these into active packages unless goals change:

- Public matchmaking
- Accounts / ranked play / persistent profiles
- Complex lobby browser
- Dedicated public infrastructure
- Final art / polished production UI (placeholders remain OK)
