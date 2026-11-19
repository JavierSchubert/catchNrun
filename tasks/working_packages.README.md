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

### Done (see CP-08)

- [x] Unit health component + synced current health
- [x] Right-click attack + chase into `attack_range`
- [x] Acquisition range vs attack range (melee)
- [x] Minimal melee attack path (instant swing, no hitbox scene yet)
- [x] Crit / lifesteal / defense hooks in `CombatDamage` (role defaults currently 0 for clear fights)
- [x] Health regeneration tick (role defaults currently 0)
- [x] Runner / Hunter elimination when health ≤ 0
- [x] Dead Runners become observers (free camera + HUD)
- [x] Enter `Phase.ENDED` and resolve win / loss
- [x] Hunter bot seeks and attacks living Runners
- [x] Melee / health automated test scene

### Still open

- [ ] Hitbox / hurtbox scenes for wind-up / projectile contact
- [ ] Attack-move (`A` + left click)
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

**Owning docs:** `construction.README.md`, `gameplay.README.md` §3–§4, `project_architecture.README.md` (`src/buildings/`, `src/construction/`)

### Open

- [ ] Placement mode, preview, and position validation
- [ ] Crystal Mine scene (one per Runner)
- [ ] Wall scene (blocks movement; updates navigation on destroy)
- [ ] Tower scene (acquires / attacks Hunter)
- [ ] Structure health and destruction
- [ ] Structure upgrades driven by configuration (health / damage / output)
- [ ] Server-authoritative build / upgrade transactions
- [ ] Navigation path recalculation when walls appear / disappear
- [ ] Building / construction test scenes

### Depends on

- Economy spend validation (can land as stubs with WP-03, or minimal crystal balance first)
- Health / combat for structure destruction and tower attacks (WP-01)

---

## WP-03 — Economy and Hunter shop (P0 / P1)

**Owning docs:** `economy.README.md`, `gameplay.README.md` economy sections, `stats.README.md` (shop applies modifiers)

### Open

- [ ] Crystal resource owned by authoritative match / player state
- [ ] Crystal Mine generation interval and `2^(level - 1)` output through level 12
- [ ] Configurable mine upgrade costs (UI must not own costs)
- [ ] Runner spending: mine / wall / tower build and upgrades
- [ ] Hunter crystals from damage dealt (`hunter_crystals_per_damage`)
- [ ] Hunter passive income from Hunter Shop / base (lower than developed mines)
- [ ] Hunter Shop purchases applying `StatModifier`s
- [ ] Centralized economy config resources
- [ ] Crystal / shop automated tests

### Depends on

- Stats modifiers already exist (CP-05)
- Damage pipeline (WP-01) for damage income
- Structures (WP-02) for mine generation and build spend

---

## WP-04 — Selection, camera, and cursors (P0 / P1)

**Owning docs:** `controls.README.md`, `selection_panel.README.md`

### Done

- [x] Edge-scrolling camera (normalized diagonals)
- [x] `C` centers camera on controlled character (while alive)
- [x] Observer keeps free camera after death

### Still open

- [ ] Left-click selection of clickable entities
- [ ] Clear selection on empty world click (as applicable)
- [ ] Clickable vs attackable capability separation (groups / components)
- [ ] Context-sensitive cursors (move / attack / invalid / attack-move)
- [ ] Selection system in `src/selection/` (state only; no HUD rules)
- [ ] Selection Panel HUD: entity info (left) + context actions (right)
- [ ] Capability-driven actions (build, upgrade, …) without hard-coding every instance
- [ ] Team / ownership rules for what actions and info are shown

### Depends on

- Units / structures existing to select (WP-02 for buildings)
- Economy / construction for upgrade / build actions (WP-02, WP-03)

### Notes

- Match camera: `game/camera/match_camera.gd`. HUD shows phase / HP / observer; selection panel still open.

---

## WP-05 — Vision, fog of war, and minimap (P1)

**Owning docs:** `gameplay.README.md` §7, `minimap.README.md`, referenced `vision.README.md` (**file missing**)

### Open

- [ ] Author `docs/vision.README.md` (referenced but absent)
- [ ] Team vision ranges and fog-of-war state
- [ ] Vision states: Unexplored / Currently Visible / Previously Seen
- [ ] Last-known entity / structure information
- [ ] `src/vision/` implementation
- [ ] Minimap presentation from known information only
- [ ] Configurable structure / unit colors or icons on minimap
- [ ] Separate Runner vs Hunter knowledge
- [ ] Moving units do not leak live positions outside vision
- [ ] Vision / minimap test coverage

### Depends on

- World entities and structures (WP-02)
- Selection / HUD shell useful but not strictly required first

---

## WP-06 — Sandbox and bot depth (P1)

**Owning docs:** `project_architecture.README.md` §8–§9, `instructions.README.md` §4

### Open

- [ ] Spawn units and structures from sandbox
- [ ] Modify crystals and stats at runtime
- [ ] Apply damage / healing; destroy selected entities
- [ ] Change structure levels; start / skip prep (skip already done)
- [ ] Toggle fog of war / reveal map / test vision ranges
- [ ] Bot attack and build behaviors for multiplayer coverage
- [ ] Component / combat / shop / building test scenes listed in architecture

### Depends on

- Features under test from WP-01 … WP-05

---

## WP-07 — Repository layout and cleanup (P2)

**Owning docs:** `project_architecture.README.md` §3–§5

### Open

- [ ] Create missing `src/` system folders as features land: `components`, `buildings`, `combat`, `construction`, `economy`, `inventory`, `items`, `selection`, `vision`
- [ ] HUD folders under `ui/hud/` (`selection_panel`, `minimap`, `resources`, `health_bar`, `stats`)
- [ ] Real `game/arena/` (and dedicated camera module if split from unit camera)
- [ ] Remove or document empty legacy shells (`components/`, `common/`, `data/`, `entities/`, `game/player/`)
- [ ] Drop unused WASD / attack input map leftovers if mouse-only controls stay the standard
- [ ] Keep scenes + primary scripts co-located per feature

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

## Suggested next milestones

Compare against `checkpoints.README.md` (first milestone = session skeleton ≈ done).

```text
Milestone A — Fight and finish
  WP-01 core melee / elimination / hunter bot / camera  ✅ landed
  Remaining: attack-move, hitboxes, ranged/magic

Milestone B — Build and earn
  WP-02 Construction (minimal Crystal Mine + Wall)
  WP-03 Economy (mine ticks + spend + hunter damage income)

Milestone C — Command and HUD
  WP-04 Selection + selection panel + cursors (camera done)
  Hunter Shop + tower attacks as extensions of B

Milestone D — Fog and map awareness
  WP-05 Vision doc + FoW + minimap

Milestone E — Hardening
  WP-06 Sandbox / bot depth
  WP-07 Layout cleanup
  WP-08 CI / export
```

---

## Explicitly out of initial scope (keep parked)

From `project_architecture.README.md` §7.4 — do not pull these into active packages unless goals change:

- Public matchmaking
- Accounts / ranked play / persistent profiles
- Complex lobby browser
- Dedicated public infrastructure
- Final art / polished production UI (placeholders remain OK)
