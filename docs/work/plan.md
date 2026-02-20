# Spirefall Phase 3: Content and Polish Implementation Plan

**Goal:** Transform Spirefall from a functional prototype into a shippable game on itch.io (HTML5) and Android. This phase adds the remaining content (3 maps, Draft mode, meta progression), complete menu flow, save/load, touch support, audio integration, visual polish, and export configuration.

**Reference:** GDD Section 13.3 (Weeks 9-12: Content and Polish)

**Prerequisites:** Phase 1 (core systems) and Phase 2 (gameplay) are complete. All 300+ GdUnit4 tests pass. The game is playable in Classic mode on the Forest Clearing map with keyboard+mouse input.

---

## Architecture Overview

Phase 3 introduces several new systems and modifies existing ones. The high-level changes are:

```
NEW SYSTEMS:
  SaveSystem (autoload)       - Persistent save/load via JSON to user://
  SettingsManager (autoload)  - Volume, controls, display prefs
  MetaProgression (autoload)  - XP, unlocks, run history
  DraftManager (autoload)     - Element draft picks, tower filtering
  SceneManager (autoload)     - Scene transitions with loading screen

NEW SCENES:
  scenes/main/MainMenu.tscn        - Title screen, entry point
  scenes/main/ModeSelect.tscn      - Classic / Draft / Endless mode picker
  scenes/main/MapSelect.tscn       - Map grid with previews
  scenes/ui/PauseMenu.tscn         - In-game pause overlay
  scenes/ui/DraftPickPanel.tscn    - Element draft pick UI
  scenes/ui/BossAnnouncement.tscn  - Boss intro splash
  scenes/ui/SettingsPanel.tscn     - Audio/display/controls settings
  scenes/maps/MountainPass.tscn    - Map 2
  scenes/maps/RiverDelta.tscn      - Map 3
  scenes/maps/VolcanicCaldera.tscn - Map 4

MODIFIED FILES:
  project.godot            - Main scene -> MainMenu, new autoloads, touch input actions
  scripts/main/Game.gd     - Parameterized map/mode, pause, return-to-menu
  scripts/autoload/GameManager.gd    - Game mode enum, draft hooks, pause, stats tracking
  scripts/autoload/UIManager.gd      - Scene navigation, pause menu, draft panel registration
  scripts/autoload/AudioManager.gd   - Crossfade, bus volume API, phase-reactive music
  scripts/autoload/EconomyManager.gd - Stats tracking for meta progression
  scripts/autoload/EnemySystem.gd    - Stats tracking, boss announcement signal
  scripts/ui/BuildMenu.gd           - Element filtering for Draft mode
  scripts/ui/GameOverScreen.gd      - Stats display, XP award, menu return
  scripts/ui/HUD.gd                 - Boss HP bar, touch-friendly sizing
```

---

## Task Groups

### Group A: Scene Navigation and Menu Flow (P0)

The game currently launches directly into gameplay. This group adds a proper menu flow: MainMenu -> ModeSelect -> MapSelect -> Game -> GameOver -> MainMenu.

---

#### Task A1: SceneManager Autoload

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 10.3

**New files:**
- `scripts/autoload/SceneManager.gd`

**Modified files:**
- `project.godot` (add autoload)

**Implementation notes:**
- Autoload singleton that manages scene transitions
- `change_scene(scene_path: String)` with optional fade transition
- Uses a `CanvasLayer` with a `ColorRect` overlay for fade-to-black transitions
- Stores `current_game_config: Dictionary` to pass parameters between scenes (mode, map, difficulty)
- Provides `go_to_main_menu()`, `go_to_game(config: Dictionary)`, `restart_game()` convenience methods
- Fade duration: 0.3s out, 0.3s in (tweened alpha)
- Signal: `scene_changing()` so systems can clean up

**Acceptance criteria:**
- [ ] Calling `SceneManager.change_scene("res://scenes/main/MainMenu.tscn")` fades out, loads scene, fades in
- [ ] `SceneManager.current_game_config` persists across scene changes
- [ ] No orphan nodes after transition

---

#### Task A2: MainMenu Scene

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 10.3

**New files:**
- `scenes/main/MainMenu.tscn`
- `scripts/main/MainMenu.gd`

**Implementation notes:**
- `Control` root node, full-screen, centered layout
- Title "SPIREFALL" in large text at top
- Buttons: Play, Settings, Credits (Collection and Leaderboards are P2, grayed out with "Coming Soon")
- Play button navigates to ModeSelect via SceneManager
- Settings button opens SettingsPanel overlay
- Credits button opens a simple scrollable label overlay
- Background: solid dark gradient or static artwork placeholder
- Trigger `AudioManager.play_music("menu")` on ready
- Update `project.godot` to set `run/main_scene="res://scenes/main/MainMenu.tscn"`

**Acceptance criteria:**
- [ ] Game launches to MainMenu, not directly into gameplay
- [ ] Play button navigates to ModeSelect with fade transition
- [ ] Settings button opens settings overlay
- [ ] All buttons have hover/press feedback

---

#### Task A3: ModeSelect Scene

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 6, Section 10.3

**New files:**
- `scenes/main/ModeSelect.tscn`
- `scripts/main/ModeSelect.gd`

**Implementation notes:**
- Display mode cards: Classic (always unlocked), Draft (unlocked at 500 XP), Endless (unlocked at 2000 XP)
- Each card shows: mode name, brief description, lock status
- Locked modes are visually grayed out with unlock requirement text
- Selecting a mode stores it in `SceneManager.current_game_config["mode"]` and navigates to MapSelect
- Back button returns to MainMenu
- Mode descriptions from GDD:
  - Classic: "30 waves of increasing difficulty. Build, maze, and survive."
  - Draft: "Start with 1 random element. Draft 2 more across 10 waves."
  - Endless: "Waves never stop. How far can you go?"

**Acceptance criteria:**
- [ ] Three mode cards displayed with correct descriptions
- [ ] Locked modes show requirement and cannot be selected
- [ ] Selected mode stored in game config, navigates to MapSelect
- [ ] Back button returns to MainMenu

---

#### Task A4: MapSelect Scene

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 9.3, Section 10.3

**New files:**
- `scenes/main/MapSelect.tscn`
- `scripts/main/MapSelect.gd`

**Implementation notes:**
- Grid of map cards (2x2 layout)
- Each card: map name, gimmick description, difficulty stars (1-4), preview thumbnail
- Forest Clearing: always unlocked, 1 star
- Mountain Pass: unlocked at 1000 XP, 2 stars
- River Delta: unlocked at 3000 XP, 3 stars
- Volcanic Caldera: unlocked at 6000 XP, 4 stars
- Locked maps show silhouette thumbnail + unlock requirement
- Selecting a map stores `SceneManager.current_game_config["map"]` and starts the game via `SceneManager.go_to_game(config)`
- Back button returns to ModeSelect
- Map preview thumbnails: initially use programmatic solid-color rectangles with map name text; replace with screenshots later

**Acceptance criteria:**
- [ ] Four map cards displayed with names, descriptions, difficulty
- [ ] Locked maps cannot be selected, show unlock requirement
- [ ] Selecting a map navigates to Game scene with correct config
- [ ] Back button returns to ModeSelect

---

#### Task A5: Modify Game.gd for Parameterized Launch

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 13.3

**Modified files:**
- `scripts/main/Game.gd`
- `scripts/autoload/GameManager.gd`

**Implementation notes:**
- `Game._ready()` reads `SceneManager.current_game_config` to determine map and mode
- Replace hardcoded `_load_map()` with dynamic map loading:
  ```gdscript
  var map_path: String = SceneManager.current_game_config.get("map", "res://scenes/maps/ForestClearing.tscn")
  ```
- Pass game mode to `GameManager.start_game(mode: String)` where mode is "classic", "draft", or "endless"
- Add `GameManager.GameMode` enum: `CLASSIC, DRAFT, ENDLESS`
- For Endless mode: set `max_waves = 999` and scale wave_config beyond wave 30
- Fallback: if `SceneManager.current_game_config` is empty (e.g., direct scene launch for testing), default to ForestClearing + Classic

**Acceptance criteria:**
- [ ] Game loads the map specified in game config
- [ ] Game mode is passed to GameManager and affects behavior
- [ ] Direct launch of Game.tscn still works (fallback defaults)
- [ ] Endless mode does not end at wave 30

---

#### Task A6: Pause Menu

**Priority:** P0 | **Effort:** Small | **GDD Ref:** Section 10.3

**New files:**
- `scenes/ui/PauseMenu.tscn`
- `scripts/ui/PauseMenu.gd`

**Modified files:**
- `scripts/main/Game.gd` (Escape key toggles pause)
- `scripts/autoload/GameManager.gd` (pause/unpause methods)

**Implementation notes:**
- `Control` overlay with semi-transparent dark background
- Buttons: Resume, Restart, Settings, Quit to Menu
- Resume: unpause and hide
- Restart: `SceneManager.restart_game()` (reloads Game.tscn with same config)
- Settings: opens SettingsPanel (shared with MainMenu)
- Quit to Menu: `SceneManager.go_to_main_menu()` (resets all manager state)
- `GameManager.toggle_pause()` sets `get_tree().paused` and emits `paused_changed(is_paused: bool)`
- PauseMenu's `process_mode` set to `PROCESS_MODE_WHEN_PAUSED`
- Escape key in Game.gd: if not placing/fusing, toggle pause

**Acceptance criteria:**
- [ ] Pressing Escape during gameplay opens pause menu
- [ ] Game logic freezes while paused (enemies stop, timers stop)
- [ ] Resume closes menu and resumes gameplay
- [ ] Quit to Menu returns to MainMenu with clean state
- [ ] Restart reloads the same map/mode

---

#### Task A7: Update GameOverScreen for Menu Flow

**Priority:** P0 | **Effort:** Small | **GDD Ref:** Section 10.3

**Modified files:**
- `scripts/ui/GameOverScreen.gd`
- `scenes/ui/GameOverScreen.tscn`

**Implementation notes:**
- Add stats display: waves survived, enemies killed, total gold earned, time played
- Add XP earned display (calculated by MetaProgression, or placeholder if MetaProgression not yet built)
- Replace "Play Again" reload with two buttons: "Play Again" (restart same config) and "Main Menu" (return to menu)
- Play Again: `SceneManager.restart_game()`
- Main Menu: `SceneManager.go_to_main_menu()`
- Stats sourced from `GameManager.run_stats` dictionary (added in Task A5)

**Acceptance criteria:**
- [ ] Game over screen shows run statistics
- [ ] Play Again restarts with same map/mode
- [ ] Main Menu returns to MainMenu scene
- [ ] No more `get_tree().reload_current_scene()` calls

---

### Group B: Maps (P0)

Three new maps with unique layouts and gimmicks. Each map is a scene + script that calls `GridManager.load_map_data()` with its grid layout.

---

#### Task B1: Map Base Class

**Priority:** P0 | **Effort:** Small | **GDD Ref:** Section 9.3

**New files:**
- `scripts/maps/MapBase.gd`

**Implementation notes:**
- `class_name MapBase extends Node2D`
- Extracts common logic from `ForestClearing.gd`: `_create_tile_visuals()`, `_on_grid_updated()`, `_get_tile_texture()`, `TILE_TEXTURES` dictionary
- Abstract methods (implemented by subclasses): `_setup_grid() -> void`, `get_map_name() -> String`, `get_spawn_points() -> Array[Vector2i]`, `get_exit_points() -> Array[Vector2i]`
- Refactor `ForestClearing.gd` to extend `MapBase` and only implement `_setup_grid()`
- Keeps map scripts focused on layout definition only

**Acceptance criteria:**
- [ ] MapBase contains all shared tile visual logic
- [ ] ForestClearing extends MapBase and still works identically
- [ ] New maps can be created by extending MapBase and implementing `_setup_grid()`

---

#### Task B2: Mountain Pass Map

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 9.3

**New files:**
- `scenes/maps/MountainPass.tscn`
- `scripts/maps/MountainPass.gd`

**Implementation notes:**
- Extends `MapBase`
- Layout: pre-built walls (UNBUILDABLE cells) create a partial S-curve maze
- Spawn at (0, 2), exit at (19, 12)
- Approximately 40% of cells are UNBUILDABLE (mountain walls), creating natural chokepoints
- Remaining cells are BUILDABLE -- players can extend the maze but have less freedom
- Wall pattern suggestion:
  - Horizontal wall rows at y=5 (x=0..14) and y=10 (x=5..19) creating S-shape
  - Vertical wall columns at x=5 (y=0..5) and x=14 (y=10..14)
  - Adjust to ensure at least one valid path exists
- PATH cells along a suggested default route (enemies repath dynamically regardless)

**Acceptance criteria:**
- [ ] Map loads and displays correctly with wall tiles
- [ ] PathfindingSystem finds valid path from spawn to exit
- [ ] Mazing is possible in open areas but walls constrain it
- [ ] Tower placement cannot occur on UNBUILDABLE cells

---

#### Task B3: River Delta Map

**Priority:** P0 | **Effort:** Large | **GDD Ref:** Section 9.3

**New files:**
- `scenes/maps/RiverDelta.tscn`
- `scripts/maps/RiverDelta.gd`

**Implementation notes:**
- Extends `MapBase`
- Layout: river (UNBUILDABLE) splits the map into 3 horizontal islands connected by bridges (narrow BUILDABLE corridors)
- River runs roughly vertically at x=7 and x=13, with bridge gaps
- 3 spawn points on left edge: (0, 2), (0, 7), (0, 12)
- 3 exit points on right edge: (19, 2), (19, 7), (19, 12)
- Bridge cells (3 cells wide) at specific y-coordinates connecting islands
- Enemies from each spawn must navigate through bridges to reach corresponding exit
- Bridges themselves are PATH (not buildable), river cells are UNBUILDABLE
- **Key challenge:** PathfindingSystem must handle multiple spawn->exit pairs. Currently `spawn_points` and `exit_points` are arrays in GridManager. Verify that AStarGrid2D pathfinding works with multiple spawn/exit pairs -- enemies should path from their assigned spawn to nearest exit
- May need to modify `EnemySystem.spawn_wave()` to distribute enemies across spawn points (round-robin or random)

**Modified files:**
- `scripts/autoload/EnemySystem.gd` (multi-spawn support if not already present)
- `scripts/autoload/PathfindingSystem.gd` (verify multi-path support)

**Acceptance criteria:**
- [ ] Map displays with river and island visuals
- [ ] 3 spawn points and 3 exit points function correctly
- [ ] Enemies distribute across spawn points
- [ ] Bridges are the only way across the river
- [ ] Mazing works on each island independently

---

#### Task B4: Volcanic Caldera Map

**Priority:** P0 | **Effort:** Large | **GDD Ref:** Section 9.3

**New files:**
- `scenes/maps/VolcanicCaldera.tscn`
- `scripts/maps/VolcanicCaldera.gd`

**Implementation notes:**
- Extends `MapBase`
- Layout: circular map with center spawn, enemies radiate outward to edges
- Spawn at center: (10, 7)
- Exits at 4 map edges: (0, 7), (19, 7), (10, 0), (10, 14)
- UNBUILDABLE ring around center (radius ~2 cells) to give enemies initial space
- UNBUILDABLE border cells at map edges near exits
- Rest is BUILDABLE -- players maze to slow enemies radiating outward
- **Key challenge:** This inverts the usual pathfinding (enemies go FROM center TO edges). PathfindingSystem treats spawn->exit directionally. Verify that enemies correctly path from center spawn to any exit. May need enemies to pick a random exit point on spawn
- Lava aesthetic: re-use UNBUILDABLE tile texture (or add a "lava" variant later)

**Modified files:**
- `scripts/autoload/EnemySystem.gd` (random exit assignment per enemy if needed)
- `scripts/enemies/Enemy.gd` (support for per-enemy exit point if needed)

**Acceptance criteria:**
- [ ] Map displays with central spawn and edge exits
- [ ] Enemies spawn from center and path outward to edges
- [ ] Players can maze around the center to create longer paths
- [ ] All 4 exits function as valid enemy destinations

---

#### Task B5: Map-Specific Tile Textures

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 11.2

**New files:**
- `assets/sprites/tiles/mountain_wall.png` (programmatic: dark gray with rock texture)
- `assets/sprites/tiles/river.png` (programmatic: blue with wave lines)
- `assets/sprites/tiles/bridge.png` (programmatic: brown planks)
- `assets/sprites/tiles/lava.png` (programmatic: orange-red glow)

**Implementation notes:**
- Create simple programmatic placeholder textures (64x64 PNG with distinct colors/patterns)
- Override `TILE_TEXTURES` in map subclasses to use map-specific tiles
- MapBase supports a `_get_custom_tile_textures() -> Dictionary` override

**Acceptance criteria:**
- [ ] Each map has visually distinct tile types
- [ ] Mountain walls look different from river cells
- [ ] Tiles are clearly distinguishable at gameplay zoom

---

### Group C: Draft Mode (P1)

Implements the element drafting mechanic where players start with 1 random element and draft 2 more.

---

#### Task C1: DraftManager Autoload

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 6.2

**New files:**
- `scripts/autoload/DraftManager.gd`

**Modified files:**
- `project.godot` (add autoload)

**Implementation notes:**
- `class_name DraftManagerClass extends Node`
- State: `drafted_elements: Array[String]`, `is_draft_active: bool`, `picks_remaining: int`
- Constants: `STARTING_ELEMENTS: int = 1`, `DRAFT_WAVES: Array[int] = [5, 10]`, `CHOICES_PER_PICK: int = 3`
- Methods:
  - `start_draft()` -- randomly assigns 1 starting element, sets picks_remaining = 2
  - `get_draft_choices() -> Array[String]` -- returns 3 random elements not yet drafted
  - `pick_element(element: String) -> void` -- adds to drafted_elements, decrements picks_remaining
  - `is_tower_available(tower_data: TowerData) -> bool` -- returns true if tower's element(s) are all in drafted_elements
  - `reset()` -- clears state
- Signals: `draft_started(starting_element: String)`, `draft_pick_available(choices: Array[String])`, `element_drafted(element: String)`
- On `GameManager.wave_completed`, if wave is in DRAFT_WAVES and picks_remaining > 0, emit `draft_pick_available`

**Acceptance criteria:**
- [ ] Starting a draft assigns 1 random element
- [ ] Draft picks trigger at waves 5 and 10
- [ ] 3 choices presented, excluding already-drafted elements
- [ ] `is_tower_available()` correctly filters by drafted elements
- [ ] Dual-element fusion towers require both elements to be drafted

---

#### Task C2: DraftPickPanel UI

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 6.2

**New files:**
- `scenes/ui/DraftPickPanel.tscn`
- `scripts/ui/DraftPickPanel.gd`

**Implementation notes:**
- Full-screen overlay (pauses game while draft is active)
- Shows 3 element cards with: element name, color, icon, list of towers that element unlocks
- Clicking a card calls `DraftManager.pick_element(element)`
- Panel hides after pick, game resumes
- Animate cards in with a slide/fade
- `process_mode = PROCESS_MODE_WHEN_PAUSED`

**Acceptance criteria:**
- [ ] Panel appears at correct waves during draft mode
- [ ] 3 element choices displayed with correct info
- [ ] Selecting an element adds it to drafted set and closes panel
- [ ] Game pauses while panel is open

---

#### Task C3: BuildMenu Element Filtering

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 6.2

**Modified files:**
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- When `DraftManager.is_draft_active` is true, filter `_available_towers` through `DraftManager.is_tower_available()`
- Re-call `_create_buttons()` whenever `DraftManager.element_drafted` fires (new towers become available)
- Gray out / hide towers whose elements have not been drafted
- Show a "Draft: [element icons]" indicator at the top of the build menu showing currently drafted elements

**Acceptance criteria:**
- [ ] In draft mode, only towers matching drafted elements appear
- [ ] New towers appear in build menu after each draft pick
- [ ] Non-draft mode shows all towers as before

---

### Group D: Save/Load and Settings (P0)

Persistent data storage for settings, meta progression, and optionally mid-game saves.

---

#### Task D1: SaveSystem Autoload

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 8.3

**New files:**
- `scripts/autoload/SaveSystem.gd`

**Modified files:**
- `project.godot` (add autoload)

**Implementation notes:**
- `class_name SaveSystemClass extends Node`
- Save path: `user://save_data.json`
- Data structure:
  ```json
  {
    "version": 1,
    "settings": { "master_volume": 1.0, "sfx_volume": 1.0, "music_volume": 0.8 },
    "progression": { "total_xp": 0, "unlocked_maps": ["forest_clearing"], "unlocked_modes": ["classic"], "run_history": [] },
    "stats": { "total_runs": 0, "total_kills": 0, "total_waves": 0, "best_wave_classic": 0 }
  }
  ```
- Methods:
  - `save() -> void` -- serialize to JSON, write to user://
  - `load_save() -> void` -- read from user://, parse JSON, populate data
  - `has_save() -> bool`
  - `reset_save() -> void` (debug/settings option)
  - `get_progression() -> Dictionary`
  - `get_settings() -> Dictionary`
  - `update_settings(key: String, value: Variant) -> void`
  - `record_run(run_data: Dictionary) -> void` -- appends to run_history, updates stats
- Auto-load save data on `_ready()`
- Auto-save after settings changes and after each run completes
- Version field for future migration support
- Error handling: if file is corrupt, reset to defaults and warn

**Acceptance criteria:**
- [ ] Save file created at `user://save_data.json` on first run
- [ ] Settings persist across game restarts
- [ ] Progression data persists across game restarts
- [ ] Corrupt save file handled gracefully (reset to defaults)
- [ ] `has_save()` returns false on first launch

---

#### Task D2: SettingsManager Autoload

**Priority:** P0 | **Effort:** Small | **GDD Ref:** Section 10.3

**New files:**
- `scripts/autoload/SettingsManager.gd`

**Modified files:**
- `project.godot` (add autoload)

**Implementation notes:**
- `class_name SettingsManagerClass extends Node`
- Reads initial values from `SaveSystem.get_settings()` on `_ready()`
- Properties: `master_volume: float`, `sfx_volume: float`, `music_volume: float`, `screen_shake: bool`, `show_damage_numbers: bool`
- Methods:
  - `set_volume(bus_name: String, linear: float)` -- converts to dB, applies to AudioServer bus
  - `apply_all()` -- applies all settings to engine (called on load)
- Signals: `settings_changed()`
- On any change, calls `SaveSystem.update_settings()` and emits signal

**Acceptance criteria:**
- [ ] Volume sliders affect audio bus volumes
- [ ] Settings persist via SaveSystem
- [ ] Applying settings on startup restores previous values

---

#### Task D3: SettingsPanel UI

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 10.3

**New files:**
- `scenes/ui/SettingsPanel.tscn`
- `scripts/ui/SettingsPanel.gd`

**Implementation notes:**
- Reusable panel (used in MainMenu and PauseMenu)
- Sections: Audio (master/SFX/music sliders), Display (screen shake toggle, damage numbers toggle)
- Each slider: HSlider with value label, range 0-100, snapped to 5
- Close/Back button
- On slider change: `SettingsManager.set_volume(...)` immediately (live preview)
- Layout: VBoxContainer with labeled rows

**Acceptance criteria:**
- [ ] Three volume sliders that control audio in real-time
- [ ] Toggle switches for display options
- [ ] Settings save automatically when changed
- [ ] Panel works when accessed from both MainMenu and PauseMenu

---

### Group E: Meta Progression (P1)

XP system that unlocks maps, modes, and provides a sense of long-term advancement.

---

#### Task E1: MetaProgression Autoload

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 8.3

**New files:**
- `scripts/autoload/MetaProgression.gd`

**Modified files:**
- `project.godot` (add autoload)

**Implementation notes:**
- `class_name MetaProgressionClass extends Node`
- Reads state from `SaveSystem.get_progression()` on `_ready()`
- XP formula per run:
  ```
  base_xp = waves_survived * 10
  kill_bonus = enemies_killed * 1
  gold_bonus = floor(total_gold_earned / 100) * 5
  victory_bonus = 200 (if won)
  total_xp = base_xp + kill_bonus + gold_bonus + victory_bonus
  ```
- Unlock thresholds (cumulative XP):
  - 500 XP: Draft mode
  - 1000 XP: Mountain Pass map
  - 2000 XP: Endless mode
  - 3000 XP: River Delta map
  - 6000 XP: Volcanic Caldera map
- Methods:
  - `calculate_run_xp(run_stats: Dictionary) -> int`
  - `award_xp(amount: int) -> void` -- adds to total, checks unlocks
  - `is_unlocked(unlock_id: String) -> bool`
  - `get_total_xp() -> int`
  - `get_new_unlocks(xp_before: int, xp_after: int) -> Array[String]` -- returns newly crossed thresholds
- Signals: `xp_awarded(amount: int, total: int)`, `unlocked(unlock_id: String)`
- Unlock IDs: `"mode_draft"`, `"mode_endless"`, `"map_mountain_pass"`, `"map_river_delta"`, `"map_volcanic_caldera"`

**Acceptance criteria:**
- [ ] XP calculated correctly from run stats
- [ ] Cumulative XP persists via SaveSystem
- [ ] Unlocks trigger at correct thresholds
- [ ] New unlocks displayed on GameOverScreen
- [ ] `is_unlocked()` used by ModeSelect and MapSelect to gate content

---

#### Task E2: GameManager Stats Tracking

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 8.3

**Modified files:**
- `scripts/autoload/GameManager.gd`
- `scripts/autoload/EconomyManager.gd`
- `scripts/autoload/EnemySystem.gd`

**Implementation notes:**
- Add `run_stats: Dictionary` to GameManager, initialized in `start_game()`:
  ```gdscript
  run_stats = {
    "waves_survived": 0,
    "enemies_killed": 0,
    "enemies_leaked": 0,
    "total_gold_earned": 0,
    "towers_built": 0,
    "fusions_made": 0,
    "start_time": Time.get_ticks_msec(),
    "elapsed_time": 0,
    "mode": "classic",
    "map": "forest_clearing",
    "victory": false,
  }
  ```
- Increment counters on relevant signals: `wave_completed`, `EnemySystem.enemy_killed`, `EconomyManager.gold_changed`, etc.
- On game over, finalize stats (elapsed_time, victory flag) and call `MetaProgression.award_xp(MetaProgression.calculate_run_xp(run_stats))`
- Signal: `run_completed(run_stats: Dictionary)`

**Acceptance criteria:**
- [ ] All stats tracked accurately during a run
- [ ] Stats passed to GameOverScreen for display
- [ ] Stats passed to MetaProgression for XP calculation
- [ ] Stats include elapsed time (formatted as mm:ss)

---

### Group F: Audio Integration (P1)

Wire up AudioManager calls throughout gameplay code. Audio files are external dependencies -- this group focuses on integration points and placeholder hooks.

---

#### Task F1: AudioManager Enhancements

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 11

**Modified files:**
- `scripts/autoload/AudioManager.gd`

**Implementation notes:**
- Add music crossfade: when `play_music()` is called while music is playing, fade out old (0.5s) then fade in new (0.5s) using Tween
- Add `set_bus_volume(bus_name: String, linear: float)` -- converts linear 0.0-1.0 to dB using `linear_to_db()`, applies to `AudioServer.set_bus_volume_db()`
- Add `play_sfx_pitched(sfx_name: String, pitch_scale: float)` for variation
- Add OGG fallback: try `.ogg` if `.wav` not found for SFX (allows both formats)
- Add `stop_sfx_all()` for scene transitions
- Support `.mp3` for music as fallback to `.ogg`
- Ensure `play_sfx` / `play_music` silently return if file not found (already does this, verify)

**Acceptance criteria:**
- [ ] Music crossfades smoothly between tracks
- [ ] Bus volume API works with SettingsManager
- [ ] Missing audio files do not cause errors (graceful fallback)

---

#### Task F2: Gameplay Audio Hooks

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 11

**Modified files:**
- `scripts/main/Game.gd`
- `scripts/towers/Tower.gd`
- `scripts/enemies/Enemy.gd`
- `scripts/autoload/GameManager.gd`
- `scripts/autoload/TowerSystem.gd`
- `scripts/autoload/EnemySystem.gd`
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- Add `AudioManager.play_sfx()` calls at these trigger points:
  - Tower placed: `"tower_place"` (in `TowerSystem.create_tower`)
  - Tower upgraded: `"tower_upgrade"` (in `TowerSystem.upgrade_tower`)
  - Tower sold: `"tower_sell"` (in `TowerSystem.sell_tower`)
  - Tower shoots: `"tower_shoot_{element}"` (in `Tower._shoot`, e.g. `"tower_shoot_fire"`)
  - Enemy killed: `"enemy_death"` (in `EnemySystem._on_enemy_died`)
  - Enemy leaked: `"enemy_leak"` (in `EnemySystem._on_enemy_reached_exit`)
  - Wave start: `"wave_start"` (in `GameManager._transition_to(COMBAT_PHASE)`)
  - Life lost: `"life_lost"` (in `GameManager.lose_life`)
  - Gold earned: `"gold_clink"` (in `EconomyManager.add_gold`, throttled to max 1 per 0.1s)
  - Build menu button click: `"ui_click"` (in `BuildMenu._on_tower_selected`)
- Add `AudioManager.play_music()` calls:
  - MainMenu: `"menu"` (Task A2)
  - Build phase: `"build_phase"`
  - Combat phase: `"combat_phase"`
  - Boss wave: `"boss_combat"` (waves 10, 20, 30)
  - Victory: `"victory"`
  - Defeat: `"defeat"`
- Music transitions happen in `GameManager._transition_to()` based on phase
- All SFX names are strings that map to filenames. If the file does not exist, `play_sfx` silently no-ops

**Acceptance criteria:**
- [ ] All trigger points call AudioManager with correct SFX names
- [ ] Music changes on phase transitions
- [ ] Boss waves use different combat music
- [ ] No errors when audio files are missing (graceful degradation)
- [ ] Gold sound is throttled to avoid spam

---

#### Task F3: Placeholder Audio Files

**Priority:** P2 | **Effort:** Small | **GDD Ref:** Section 11

**New files:**
- `assets/audio/sfx/*.wav` (generated procedural tones)
- `assets/audio/music/*.ogg` (generated ambient loops)

**Implementation notes:**
- Use a tool like sfxr/jsfxr to generate simple placeholder SFX:
  - `tower_place.wav`, `tower_upgrade.wav`, `tower_sell.wav`
  - `tower_shoot_fire.wav`, `tower_shoot_water.wav`, etc.
  - `enemy_death.wav`, `enemy_leak.wav`
  - `wave_start.wav`, `life_lost.wav`, `gold_clink.wav`, `ui_click.wav`
- For music: generate simple ambient loops using a tool or source CC0 tracks
  - `menu.ogg`, `build_phase.ogg`, `combat_phase.ogg`, `boss_combat.ogg`, `victory.ogg`, `defeat.ogg`
- These are temporary -- final audio is an external art dependency
- Document the expected file list in `assets/audio/README.md`

**Acceptance criteria:**
- [ ] All expected audio files exist (even if placeholder quality)
- [ ] Game plays with sound effects and music
- [ ] Audio README documents the full expected file manifest

---

### Group G: Touch Support and Mobile UI (P0)

Make the game playable on touchscreens for Android and mobile browsers.

---

#### Task G1: Touch Input Handling

**Priority:** P0 | **Effort:** Large | **GDD Ref:** Section 12

**Modified files:**
- `scripts/main/Game.gd`
- `project.godot` (input settings)

**Implementation notes:**
- Add `InputEventScreenTouch` and `InputEventScreenDrag` handling in `Game._unhandled_input()`:
  - **Single tap** = left click (place tower / select tower)
  - **Two-finger drag** = camera pan (replace WASD on mobile)
  - **Pinch zoom** = camera zoom (replace scroll wheel on mobile)
  - **Long press** (0.5s hold without move) = right click context (cancel placement, show tower info)
  - **Double tap** = start wave early
- Track touch state: `_touches: Dictionary` mapping finger index to position
- Pinch zoom: track distance between 2 touch points, scale camera.zoom proportionally
- Emulate mouse events: Godot 4 can emulate mouse from touch (`Input.emulate_mouse_from_touch` in project settings), but we want custom multi-touch, so set `emulate_mouse_from_touch = false` and handle everything manually
- Alternatively, keep `emulate_mouse_from_touch = true` for basic single-touch and only add custom handlers for multi-touch gestures. This is simpler and recommended
- Add to project.godot:
  ```
  [input_devices]
  pointing/emulate_mouse_from_touch=true
  pointing/emulate_touch_from_mouse=true
  ```

**Acceptance criteria:**
- [ ] Tapping places towers and selects towers
- [ ] Two-finger drag pans the camera
- [ ] Pinch gesture zooms the camera
- [ ] All existing mouse/keyboard input still works
- [ ] Touch input does not interfere with UI button presses

---

#### Task G2: Mobile-Friendly UI Sizing

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** Section 12

**Modified files:**
- `scenes/ui/HUD.tscn`
- `scenes/ui/BuildMenu.tscn`
- `scenes/ui/TowerInfoPanel.tscn`
- `scripts/ui/HUD.gd`
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- Minimum touch target size: 48x48 pixels (Android Material guidelines)
- BuildMenu buttons: increase from 96x64 to 112x72, ensure scroll works with touch drag
- TowerInfoPanel buttons (upgrade/sell/fuse): minimum 48px height
- HUD text: minimum 14px font size
- Add `is_mobile() -> bool` helper to detect touch devices:
  ```gdscript
  func is_mobile() -> bool:
      return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
  ```
- Conditionally increase sizes on mobile
- Ensure all `ScrollContainer` nodes work with touch drag (Godot 4 supports this natively)
- Test with `emulate_touch_from_mouse` enabled in project settings

**Acceptance criteria:**
- [ ] All interactive elements meet 48x48px minimum on mobile
- [ ] Build menu scrolls with touch drag
- [ ] Text is readable on a 6-inch phone screen
- [ ] Desktop UI is unchanged

---

### Group H: Boss Encounter Polish (P1)

Boss fights at waves 10, 20, 30 already function mechanically. This group adds presentation.

---

#### Task H1: Boss HP Bar

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 5.3

**New files:**
- `scenes/ui/BossHPBar.tscn`
- `scripts/ui/BossHPBar.gd`

**Modified files:**
- `scripts/ui/HUD.gd` (show/hide boss HP bar)

**Implementation notes:**
- Full-width bar at top of screen (below HUD), only visible during boss waves
- Shows boss name, HP bar (ProgressBar styled with boss element color), and HP text (current/max)
- Boss enemies have `enemy_data.is_boss == true` -- HUD listens for `EnemySystem.enemy_spawned` and checks
- Bar updates each frame while boss is alive (read `boss.current_hp`)
- Hides when boss dies or wave ends
- Multiple bosses (minion spawns) should not trigger -- only the main boss entity

**Acceptance criteria:**
- [ ] Boss HP bar appears at top of screen when boss spawns
- [ ] HP bar updates smoothly as boss takes damage
- [ ] Boss name and element color displayed
- [ ] Bar hides when boss is killed

---

#### Task H2: Boss Announcement Splash

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 5.3

**New files:**
- `scenes/ui/BossAnnouncement.tscn`
- `scripts/ui/BossAnnouncement.gd`

**Implementation notes:**
- Full-screen overlay that flashes briefly (2 seconds) when a boss wave starts
- Shows boss name in large text with element color, brief subtitle with boss ability hint
- Animate: slide in from top, hold 1.5s, fade out 0.5s
- Triggered by `GameManager.wave_started` when wave is a boss wave (10, 20, 30)
- Does NOT pause the game -- purely visual overlay
- Boss names from enemy resources:
  - Wave 10: Ember Titan (fire)
  - Wave 20: Glacial Wyrm (ice)
  - Wave 30: Chaos Elemental (all elements)

**Acceptance criteria:**
- [ ] Announcement appears at start of boss waves
- [ ] Boss name and element color correct
- [ ] Animation plays smoothly without disrupting gameplay
- [ ] Announcement does not appear for non-boss waves

---

### Group I: Visual Polish (P1)

Improve the visual experience beyond programmer placeholders. Focus on effects that can be done programmatically (no external art dependency).

---

#### Task I1: Tower Range Indicator

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 10.1

**Modified files:**
- `scripts/main/Game.gd`
- `scripts/ui/TowerInfoPanel.gd`

**Implementation notes:**
- When a tower is selected (or during placement ghost), draw a semi-transparent circle showing attack range
- Use a `draw_arc()` or `draw_circle()` call in a custom `Node2D` child, or a `Sprite2D` with a ring texture
- Color: element color at 20% alpha
- For placement ghost: show range around ghost position
- For selected tower: show range around tower position
- Remove indicator when tower is deselected or placement cancelled

**Acceptance criteria:**
- [ ] Range circle visible during tower placement
- [ ] Range circle visible when tower is selected
- [ ] Circle radius matches tower's actual range_cells * CELL_SIZE
- [ ] Circle uses tower's element color

---

#### Task I2: Enemy HP Bars

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 10.1

**Modified files:**
- `scripts/enemies/Enemy.gd`
- `scenes/enemies/BaseEnemy.tscn`

**Implementation notes:**
- Small HP bar above each enemy sprite
- `ProgressBar` or custom `draw()` in a child Node2D
- Green when > 50% HP, yellow 25-50%, red < 25%
- Only visible when enemy has taken damage (hide at full HP to reduce clutter)
- Width: 40px, height: 4px, offset above sprite by 20px
- Boss enemies: do NOT show individual HP bar (they have the big HUD bar from Task H1)

**Acceptance criteria:**
- [ ] HP bars appear above enemies when damaged
- [ ] Color changes based on HP percentage
- [ ] HP bars hidden at full HP
- [ ] Boss enemies do not show individual HP bars

---

#### Task I3: Particle Effects

**Priority:** P2 | **Effort:** Medium | **GDD Ref:** Section 11.2

**New files:**
- `scenes/effects/particles/` directory with GPUParticles2D scenes

**Implementation notes:**
- Create `GPUParticles2D` effects for:
  - Tower shoot: small burst at tower position (element colored)
  - Projectile impact: burst at hit position (element colored)
  - Enemy death: pop/explosion (small, white)
  - Tower placement: dust poof
  - Tower upgrade: sparkle upward
- Each effect is a PackedScene that auto-frees after emission completes (`one_shot = true`, `emitting = true` on `_ready()`)
- Use `CanvasItemMaterial` for additive blending on energy effects (lightning, fire)
- Effects spawned by existing signal connections in Game.gd

**Acceptance criteria:**
- [ ] Visual feedback for tower shots, hits, enemy deaths
- [ ] Effects are element-colored where appropriate
- [ ] Effects auto-cleanup (no orphan nodes)
- [ ] Particle count stays reasonable (< 500 particles total on screen)

---

#### Task I4: Wave Progress Indicator

**Priority:** P1 | **Effort:** Small | **GDD Ref:** Section 10.1

**Modified files:**
- `scripts/ui/HUD.gd`
- `scenes/ui/HUD.tscn`

**Implementation notes:**
- Add a wave progress bar or segment indicator to the HUD
- Shows: current wave / max waves as both text and visual bar
- During combat: show enemies remaining count (text: "12 remaining")
- During build phase: show countdown timer (if auto-start timer is active)
- Build phase timer: show seconds remaining as "Next wave in: 15s"
- Wave number text already exists in HUD -- enhance with progress bar beneath it

**Acceptance criteria:**
- [ ] Wave progress visually displayed as a bar or segments
- [ ] Enemy count shown during combat phase
- [ ] Build timer countdown shown during build phase
- [ ] Clear distinction between build and combat phase states

---

### Group J: Endless Mode (P1)

Endless mode generates waves beyond the 30 defined in wave_config.json.

---

#### Task J1: Endless Wave Generation

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 6.3

**Modified files:**
- `scripts/autoload/EnemySystem.gd`
- `scripts/autoload/GameManager.gd`

**Implementation notes:**
- When mode is ENDLESS and wave > 30, procedurally generate wave data:
  - Enemy count: `base_count + (wave - 30) * 2`
  - HP multiplier: `1.0 + (wave - 30) * 0.15` applied to base HP
  - Speed multiplier: `1.0 + (wave - 30) * 0.02` (capped at 2.0x)
  - Gold multiplier: `1.0 + (wave - 30) * 0.1`
  - Every 10th wave beyond 30 is a boss wave (cycling through the 3 bosses)
  - Every 5th wave introduces a new enemy type mix
- Enemy type selection: weighted random from all 10 types, shifting toward harder types as waves increase
- Modify `EnemySystem.spawn_wave()` to check if wave > configured waves and generate on the fly
- GameManager in ENDLESS mode: never transitions to GAME_OVER on wave_completed, only on lives == 0

**Acceptance criteria:**
- [ ] Waves continue past 30 in Endless mode
- [ ] Difficulty scales progressively
- [ ] Boss waves cycle at intervals
- [ ] Game only ends on defeat (lives == 0)
- [ ] Leaderboard-ready: wave number tracked for high score

---

### Group K: Export and Platform (P0)

Configure Godot export presets for HTML5 and Android.

---

#### Task K1: HTML5 Export Configuration

**Priority:** P0 | **Effort:** Small | **GDD Ref:** Section 12

**New files:**
- `export_presets.cfg`

**Implementation notes:**
- Add Web export preset in Godot editor or create `export_presets.cfg`
- Settings:
  - VRAM texture compression: ETC2 (for WebGL2 compatibility)
  - Export type: Regular (not thread-based, for broader browser support)
  - Head include: viewport meta tag for mobile scaling
  - Custom HTML shell: optional, can use default initially
- Output: `exports/web/` directory
- Test in Chrome and Firefox
- Ensure `gl_compatibility` renderer is set (already configured)
- Add `exports/` to `.gitignore`

**Acceptance criteria:**
- [ ] Game exports to HTML5 without errors
- [ ] Game runs in Chrome and Firefox
- [ ] No WebGL errors in console
- [ ] Game fits in browser viewport with correct aspect ratio

---

#### Task K2: Android Export Configuration

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 12

**Modified files:**
- `export_presets.cfg`

**Implementation notes:**
- Add Android export preset
- Settings:
  - Package name: `com.spirefall.game`
  - Min SDK: 24 (Android 7.0)
  - Target SDK: 34
  - Screen orientation: Landscape
  - VRAM texture compression: ETC2
- Requires Android SDK, JDK, and export templates installed locally
- Debug APK for testing, release AAB for store
- Touch input must work (Task G1 prerequisite)

**Acceptance criteria:**
- [ ] Game exports to APK without errors
- [ ] APK installs and runs on Android device/emulator
- [ ] Touch input works on Android
- [ ] Landscape orientation enforced

---

#### Task K3: Performance Profiling Pass

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** Section 12

**Implementation notes:**
- Profile the game under stress conditions:
  - Wave 30 with 50+ enemies on screen
  - 20+ towers active and firing
  - Boss with ground effects active
- Target: 60 FPS on desktop, 30 FPS on mid-range Android
- Memory budget: < 200MB web, < 300MB Android
- Check for:
  - Object pool efficiency (enemy/projectile reuse)
  - Pathfinding recalculation time (< 16ms)
  - Draw call count (batch sprite draws)
  - Per-frame allocations (avoid `new` in `_process`)
- Use Godot's built-in profiler and monitor
- Document findings and optimize bottlenecks

**Acceptance criteria:**
- [ ] 60 FPS maintained on desktop with 50 enemies + 20 towers
- [ ] No frame spikes > 32ms during pathfinding recalculation
- [ ] Memory usage stays within budget
- [ ] Performance report documented

---

## Dependency Graph

```
Phase 3 Task Dependencies
=========================

GROUP A: Scene Navigation (must come first -- everything depends on menu flow)
  A1 (SceneManager) ──> A2 (MainMenu) ──> A3 (ModeSelect) ──> A4 (MapSelect)
       │                                        │
       │                                        v
       ├──> A5 (Game.gd parameterized) ────────[needs A1, A3]
       │         │
       │         v
       ├──> A6 (PauseMenu) ───────────────────[needs A1, A5]
       │
       └──> A7 (GameOverScreen update) ────────[needs A1]

GROUP B: Maps (needs A5 for dynamic map loading, B1 first)
  B1 (MapBase) ──> B2 (Mountain Pass)
       │       ──> B3 (River Delta)
       │       ──> B4 (Volcanic Caldera)
       └──────────> B5 (Map Tile Textures)

GROUP C: Draft Mode (needs A3 for mode selection, A5 for mode parameter)
  C1 (DraftManager) ──> C2 (DraftPickPanel)
       │            ──> C3 (BuildMenu filtering)

GROUP D: Save/Load (independent, but feeds into E and A)
  D1 (SaveSystem) ──> D2 (SettingsManager) ──> D3 (SettingsPanel)
       │
       └──> feeds into E1 (MetaProgression)

GROUP E: Meta Progression (needs D1 for persistence)
  D1 ──> E1 (MetaProgression) ──> E2 (Stats tracking)
              │
              └──> feeds into A3 (mode locks), A4 (map locks), A7 (XP display)

GROUP F: Audio (independent, but needs F1 before F2)
  F1 (AudioManager enhancements) ──> F2 (Gameplay hooks) ──> F3 (Placeholder files)

GROUP G: Touch Support (independent of menu flow)
  G1 (Touch input) ──> G2 (Mobile UI sizing)

GROUP H: Boss Polish (independent)
  H1 (Boss HP bar)
  H2 (Boss announcement)

GROUP I: Visual Polish (independent)
  I1 (Range indicator)
  I2 (Enemy HP bars)
  I3 (Particle effects) ── P2, do last
  I4 (Wave progress indicator)

GROUP J: Endless Mode (needs A5 for mode parameter)
  A5 ──> J1 (Endless wave generation)

GROUP K: Export (do last, after all content)
  K1 (HTML5 export)
  K2 (Android export) ──[needs G1 touch support]
  K3 (Performance profiling)
```

---

## Recommended Implementation Order

Tasks are ordered to maximize shippability at each milestone. After each week, the game should be in a playable, demonstrable state.

### Week 1: Foundation (Shippable as single-map Classic with menus)

| Order | Task | Group | Priority | Effort | Description |
|-------|------|-------|----------|--------|-------------|
| 1 | D1 | Save/Load | P0 | Medium | SaveSystem autoload |
| 2 | D2 | Save/Load | P0 | Small | SettingsManager autoload |
| 3 | A1 | Navigation | P0 | Medium | SceneManager autoload |
| 4 | A2 | Navigation | P0 | Medium | MainMenu scene |
| 5 | A3 | Navigation | P0 | Medium | ModeSelect scene |
| 6 | A4 | Navigation | P0 | Medium | MapSelect scene |
| 7 | A5 | Navigation | P0 | Medium | Game.gd parameterized launch |
| 8 | A6 | Navigation | P0 | Small | PauseMenu |
| 9 | A7 | Navigation | P0 | Small | GameOverScreen update |
| 10 | D3 | Save/Load | P0 | Medium | SettingsPanel UI |

**Week 1 milestone:** Full menu flow (MainMenu -> ModeSelect -> MapSelect -> Game -> GameOver -> MainMenu) with settings persistence. Single map, Classic mode only, but proper game loop.

### Week 2: Content (3 new maps, Draft mode, meta progression)

| Order | Task | Group | Priority | Effort | Description |
|-------|------|-------|----------|--------|-------------|
| 11 | B1 | Maps | P0 | Small | MapBase class extraction |
| 12 | B2 | Maps | P0 | Medium | Mountain Pass map |
| 13 | B3 | Maps | P0 | Large | River Delta map |
| 14 | B4 | Maps | P0 | Large | Volcanic Caldera map |
| 15 | E1 | Meta | P1 | Medium | MetaProgression autoload |
| 16 | E2 | Meta | P1 | Small | GameManager stats tracking |
| 17 | C1 | Draft | P1 | Medium | DraftManager autoload |
| 18 | C2 | Draft | P1 | Medium | DraftPickPanel UI |
| 19 | C3 | Draft | P1 | Small | BuildMenu element filtering |

**Week 2 milestone:** All 4 maps playable. Draft mode functional. XP system tracking progress and unlocking content.

### Week 3: Polish (audio, touch, boss encounters, visual)

| Order | Task | Group | Priority | Effort | Description |
|-------|------|-------|----------|--------|-------------|
| 20 | G1 | Touch | P0 | Large | Touch input handling |
| 21 | G2 | Touch | P0 | Medium | Mobile-friendly UI sizing |
| 22 | F1 | Audio | P1 | Medium | AudioManager enhancements |
| 23 | F2 | Audio | P1 | Medium | Gameplay audio hooks |
| 24 | H1 | Boss | P1 | Small | Boss HP bar |
| 25 | H2 | Boss | P1 | Small | Boss announcement splash |
| 26 | I1 | Visual | P1 | Small | Tower range indicator |
| 27 | I2 | Visual | P1 | Small | Enemy HP bars |
| 28 | I4 | Visual | P1 | Small | Wave progress indicator |
| 29 | J1 | Endless | P1 | Medium | Endless wave generation |

**Week 3 milestone:** Game is touch-playable. Audio hooks ready (plays sounds when files exist). Boss fights have proper presentation. Visual feedback for towers and enemies.

### Week 4: Export and Final Polish

| Order | Task | Group | Priority | Effort | Description |
|-------|------|-------|----------|--------|-------------|
| 30 | K1 | Export | P0 | Small | HTML5 export configuration |
| 31 | K2 | Export | P1 | Medium | Android export configuration |
| 32 | K3 | Export | P1 | Medium | Performance profiling pass |
| 33 | B5 | Maps | P1 | Small | Map-specific tile textures |
| 34 | F3 | Audio | P2 | Small | Placeholder audio files |
| 35 | I3 | Visual | P2 | Medium | Particle effects |

**Week 4 milestone:** Game exported to HTML5 for itch.io. Android APK builds. Performance validated. Placeholder audio and particles in place.

---

## Summary

| Metric | Count |
|--------|-------|
| Total tasks | 35 |
| P0 (must-have) | 15 |
| P1 (important) | 16 |
| P2 (nice-to-have) | 4 |
| New files | ~40 (scripts + scenes + resources) |
| Modified files | ~18 |
| New autoloads | 5 (SceneManager, SaveSystem, SettingsManager, MetaProgression, DraftManager) |
| New scenes | 10 |
| Estimated effort | Small: 12, Medium: 17, Large: 4, X-Large: 0 |

### P0 Critical Path (minimum viable shipped game)

The absolute minimum to ship on itch.io is the P0 task chain:

```
D1 -> D2 -> A1 -> A2 -> A3 -> A4 -> A5 -> A6 -> A7 -> D3 -> B1 -> B2 -> B3 -> B4 -> G1 -> G2 -> K1
```

This gives: menu flow, 4 maps, save/settings, touch support, HTML5 export. Draft mode, meta progression, audio, and visual polish can follow as P1 tasks or post-launch updates.
