# UI, Settings, and Audio

Owns lobby presentation, the persistent settings dock, audio buses / playlist behavior, and the debug sandbox chrome.

---

## 1. Autoloads

| Autoload | Script | Role |
| --- | --- | --- |
| `SettingsManager` | `autoloads/settings_manager.gd` | Loads / saves `user://settings.cfg`; syncs Music/SFX volume + mute onto `SoundManager`; optional fullscreen |
| `SoundManager` | `autoloads/sound_manager.gd` | SFX pool + music playlist; applies bus volumes; starts music at boot |

Load order in `project.godot`: `SettingsManager` before `SoundManager`. Settings re-applies bus values deferred, then calls `ensure_music()`.

---

## 2. Audio buses

Layout file: `default_bus_layout.tres` (wired via `project.godot` → `[audio] buses/default_bus_layout`).

```text
Master
 ├── Music
 └── SFX
```

Defaults on first run (linear 0–1):

| Bus | Default volume | Default muted |
| --- | --- | --- |
| Music | `0.75` | `false` |
| SFX | `0.85` | `false` |

Persisted keys in `user://settings.cfg`:

```text
[audio]
music_volume
sfx_volume
music_muted
sfx_muted

[video]
fullscreen
```

Zero volumes from a broken first save are ignored on load so music does not stay silent.

---

## 3. SoundManager behavior

### 3.1. Loading

- **MP3** streams are loaded from raw file bytes (`AudioStreamMP3.data`) so playback works even when `.import` files are invalid.
- Other formats use `ResourceLoader` when available.

### 3.2. Playlist (persistent across scenes)

Playlist order:

```text
osrs_bh1.mp3 -> osrs_bh2.mp3 -> osrs_bh3.mp3 -> (loop)
```

| API | Behavior |
| --- | --- |
| `ensure_music()` | Starts the playlist only if nothing is playing. Safe to call from every scene. |
| `play_music(type, restart=false)` | Switches only when `type` differs from the current track (or `restart` is true). |
| Track `finished` | Advances to the next playlist entry automatically. |

Scenes should call `SoundManager.ensure_music()` (or rely on boot). Do **not** call `play_music` with a different track per scene unless an intentional theme change is required.

### 3.3. SFX

| Enum | Asset | Typical use |
| --- | --- | --- |
| `UI` | `assets/audio/sfx/UI Pop.mp3` | Animated buttons / UI clicks |
| `ENEMY_HIT` | `assets/audio/sfx/EnemyHit.wav` | Combat |
| `COIN_DROP` | `assets/audio/sfx/coin_drop.mp3` | Economy feedback (reserved) |

UI clicks: `SoundManager.play_ui()` (also wired from `AnimatedButton` when `play_click_sound` is true).

World combat / economy feedback numbers (white / yellow / green / cyan crystal rise-and-fade) are local FX in `src/fx/floating_number.gd`, not audio — see `controls.README.md` §5.2.

---

## 4. Settings dock (every scene)

Scene: `ui/widgets/settings_menu/settings_menu.tscn`  
Helper: `SettingsMenu.attach(parent)`

Layout:

- Gear button (`AnimatedButton` 64px) on the **right** edge (slightly below vertical center so it clears the sandbox Tests panel).
- Opens an audio overlay with Music + SFX rows (`audio_control_v2`), mute icons from `assets/sprites/buttons/sound.png` atlases.

Attached from:

- Lobby (`ui/lobby/lobby.gd`)
- Role selection (`ui/role_selection/role_selection.gd`)
- Match HUD (`game/match/hud.gd`)

---

## 5. Lobby UI

Files: `ui/lobby/lobby.tscn` + `lobby.gd`

- Shell layout (wallpaper, veil, card, connect / lobby boxes) lives in the `.tscn`.
- Shared StyleBoxes under `ui/styles/` (`card_panel_style`, button / line-edit / item-list styles).
- Script wires WebSocket host/join, roster refresh, and continue.
- `NetworkManager` uses Godot's high-level multiplayer API over WebSockets. The game-owned server is authoritative; the first registered player is the lobby host.

Role selection follows the same pattern: `ui/role_selection/role_selection.tscn` shell + side-panel StyleBoxes; dynamic player rows and action buttons remain code-filled.

---

## 6. Sandbox chrome (debug)

File: `game/sandbox/sandbox_panel.gd`  
Visible when `LaunchOptions.sandbox_enabled` (debug builds, `--sandbox`, or browser builds; never for bots / headless). In browsers, shown only to the lobby host connected to a dedicated game server. Runner/Hunter actions request server-managed test bots, and Skip is enabled only during Runner preparation.

| Panel | Anchor | Contents |
| --- | --- | --- |
| Action bar | Top-left (compact ~780px) | Native: Host, Runner/Hunter icon buttons, quick start, continue, skip, reset; Headless **on by default**; Godot path. Browser host: Runner/Hunter bot requests, quick start, continue, skip, reset |
| Tests | Top-right (native only) | Open lobby / roles / game alone |
| Status + game log | Top-left, stacked **directly under** the action bar | Phase, peers, last action text, scrolling game log |

Every panel has a **Minimize / Expand** button in its header; a minimized panel shrinks to its header and keeps its anchor corner. `G` (god mode) minimizes all panels at once, or expands them all again when everything is already minimized. `G` is ignored while the Godot-path field has focus.

Match HUD status sits **top-center under** the action bar so it does not collide with sandbox chrome. The log stacks under the action bar (a minimized bar pulls it up); the minimap keeps the bottom-left corner alone, the selection strip is bottom-center (~580×196), and the Runner building panel (~420×600) owns the bottom-right corner (`game/match/hud.tscn`). The Hunter reward panel temporarily uses that same bottom-right area when a level-up is waiting. Build vs manage visibility is gated by `HudMode` (`src/hud/hud_mode.gd`). Shared HUD widget: `ui/hud/widgets/stat_icon_row.tscn`. Optional `ui/widgets/ui_kit/ui_kit.tscn` may instance the building panel for editor gallery previews. Sandbox hosts a top-right **Stats (active)** panel to bump crit / lifesteal / damage / regen on the controlled character for combat FX testing.

### 6.1. Start-menu Sandbox (Runner + Hunter)

The lobby's **Sandbox** button (hidden in browsers; also `--scene=sandbox`) calls `GameManager.prepare_sandbox()` and opens the match scene offline with two characters: the Runner (peer 1) and a Hunter (peer 1000, `GameManager.SANDBOX_HUNTER_ID`). The Hunter phase is already open, both sides hold `SANDBOX_CRYSTALS`, and they spawn 900 px apart (outside the Hunter's 500 acquisition range).

- **Switching:** click a character in the world, or use the Runner / Hunter buttons in the top-right *Sandbox* panel (the buttons also center the camera). The selected character is the one you play: `GameManager.local_peer_id()` returns it, and the HUD, build panel, crystal bar, minimap colors, camera `C`, RMB commands and construction requests all follow it. Nothing else in the game knows about the sandbox.
- **Idle Hunter:** the Hunter you are not playing does not auto-acquire targets (it still finishes an explicit order you gave it before switching).
- **No match end:** a fallen character stays down; **Restart** respawns both and clears buildings, **Exit** returns to the start menu.
- Outside the sandbox `local_peer_id()` is simply the network peer id, so online play is unchanged.

---

## 7. Related map / camera notes

- Active match map: `game/maps/arena_plateau.tscn` (lava / `tiles/v3` tileset), not the space atlas.
- Optional props + editor spawn-ring preview on the arena; gizmos hide at runtime.
- Camera overscroll, UI-aware edge scroll, and no kill-recenter: `docs/controls.README.md` §2.
- Optional style gallery: `ui/widgets/ui_kit/ui_kit.tscn`.
