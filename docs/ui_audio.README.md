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

File: `ui/lobby/lobby.gd`

- Wallpaper + dark card presentation.
- **ENet only:** `Host local` / `Join local` (no Steam host / invite buttons in the lobby UI).
- Steam may still exist in `NetworkManager` for future use; the lobby path users see is Godot multiplayer API / ENet.

---

## 6. Sandbox chrome (debug)

File: `game/sandbox/sandbox_panel.gd`  
Visible when `LaunchOptions.sandbox_enabled` (debug builds or `--sandbox`; never for bots / headless).

| Panel | Anchor | Contents |
| --- | --- | --- |
| Action bar | Top-left (compact ~780px) | Host, Runner/Hunter icon buttons, quick start, continue, skip, reset; Headless **on by default**; Godot path |
| Tests | Top-right | Open lobby / roles / game alone |
| Status | Bottom-right | Phase, peers, last action text |

Match HUD status sits **top-center under** the action bar so it does not collide with sandbox chrome. Minimap stays bottom-left; selection strip bottom-center.

---

## 7. Related map / camera notes

- Active match map: `game/maps/arena_plateau.tscn` (lava / `tiles/v3` tileset), not the space atlas.
- Camera overscroll padding is owned by `docs/controls.README.md` §2 (`MatchCamera.bound_padding`).
