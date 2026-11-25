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

### Open (Hunter side — not requested yet)

- [ ] Hunter crystals from damage dealt (`hunter_crystals_per_damage`)
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

**Owning docs:** `gameplay.README.md` §7, `minimap.README.md`, referenced `vision.README.md` (**file missing**)

### Done (partial, pre-FoW — see CP-10 / CP-14)

- [x] Live minimap with map asset + unit pixels (own green / runners blue / hunter red)
- [x] Relative world→minimap position mapping
- [x] Minimap color rules documented in `minimap.README.md` §2.1
- [x] Camera frustum outline on minimap
- [x] Minimap LMB recenters camera
- [x] Minimap RMB move / Shift+RMB green chain / A+LMB attack-move / Shift+A+LMB red attack-chain

### Open

- [ ] Author `docs/vision.README.md` (referenced but absent)
- [ ] Team vision ranges and fog-of-war state
- [ ] Vision states: Unexplored / Currently Visible / Previously Seen
- [ ] Last-known entity / structure information
- [ ] `src/vision/` implementation
- [ ] Minimap presentation from known information only (hide units outside vision)
- [ ] Configurable structure icons on minimap
- [ ] Separate Runner vs Hunter knowledge
- [ ] Moving units do not leak live positions outside vision
- [ ] Vision / minimap test coverage

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

Combat and regen feedback as rising world-space numbers that spawn near the entity whose health changed.

### Open

- [ ] Global floating-number popup system (autoload or shared FX factory) used by all combat / regen sites
- [ ] Spawn at a **random offset around the affected entity** (damage on the target that was hit; lifesteal / regen on the unit that gained HP)
- [ ] Numbers rise upward and fade out after spawn
- [ ] Color map:
  - normal hit damage → **white**
  - crit hit damage → **yellow**
  - lifesteal amount → **green**
  - HP regen tick → **green**
- [ ] Wire into melee resolve (damage + crit + lifesteal) and health regen tick
- [ ] Local-only presentation (or host-authoritative events with local FX) without breaking multiplayer sync
- [ ] **Blocked until user provides an example function** for the preferred popup API / motion style

### Depends on

- Existing melee + regen pipeline (WP-01 / CP-08)

### Notes

- Prefer one global `spawn_floating_number(world_pos, value, kind)` entry point so hunters, runners, structures, and future DOT sources stay DRY.

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

### Open

- [ ] Authoritative player **level** + **XP** state (host-owned; replicated to clients)
- [ ] XP curve where **each level requires more XP than the previous** (configurable formula / table)
- [ ] Grant XP from agreed sources (document first: e.g. damage dealt, kills, time alive — placeholders OK until economy/combat hooks land)
- [ ] Level-up applies agreed rewards (document first: e.g. stat bumps via `StatModifier`, or none until tuned)
- [ ] Selection panel: **larger ring around the portrait** that fills with **violet** as XP progresses toward the next level
- [ ] Show current level somewhere on the selection panel (near portrait / ring)
- [ ] Empty selection keeps grey portrait; XP ring hidden or empty when nothing selected
- [ ] Sandbox / test hook to add XP for playtests (optional)

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

## Suggested next milestones

Compare against `checkpoints.README.md` (first milestone = session skeleton ≈ done).

```text
Milestone A — Fight and finish
  WP-01 core melee / elimination / hunter bot / attack-move / chains  ✅ landed (CP-08 / CP-14)
  Remaining: hitboxes, ranged/magic, combat tuning
  WP-09 floating hit / heal numbers (needs your example popup function first)
  WP-11 Hunter animated weapon on hit
  WP-13 Bigger centered world health bar + name + level rhombus + HP tick lines
  WP-15 Skins / shaders / movement animations

Milestone B — Build and earn
  WP-02 Construction: grid foundation ✅ (CP-11); match-integrated build UI + Wall / Tower / Crystal Mine ✅ (CP-15)
  WP-03 Economy: Runner mine ticks + spend ✅ (CP-15); hunter damage income / Hunter Shop still open
  WP-14 Player XP / levels + violet portrait XP ring

Milestone C — Command and HUD
  WP-04 World selection ✅ (CP-09); selection strip ✅ (CP-10); camera drag / edge-scroll ✅ (CP-14)
  Remaining: cursors / context actions
  WP-10 In-game chat
  Hunter Shop + tower attacks as extensions of B

Milestone D — Fog and map awareness
  WP-05 Vision doc + FoW still open; live minimap + command clicks ✅ (CP-10 / CP-14)

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
