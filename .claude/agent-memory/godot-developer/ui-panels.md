# UI Panel Patterns

## MainMenu (Task A2)
- Root: Control with full-rect anchors, script `scripts/main/MainMenu.gd`
- Uses `unique_name_in_owner = true` on interactive nodes for `%NodeName` access
- `@onready` with `%` syntax for node references (e.g., `%PlayButton`)
- Overlays (Settings, Credits) are PanelContainer children of root, hidden by default
- Toggle pattern: hide other overlay, then toggle self (`visible = not visible`)
- `connect_buttons()` and `apply_button_styles()` extracted as public methods for testability
- Button connections check `is_connected()` before connecting to be idempotent
- StyleBox overrides applied via `add_theme_stylebox_override("hover", StyleBoxFlat)` and `"pressed"`

## ModeSelect (Task A3)
- Root: Control with full-rect anchors, script `scripts/main/ModeSelect.gd`
- 3 mode cards (Classic/Draft/Endless) as PanelContainer in HBoxContainer
- Each card: PanelContainer > VBoxContainer > NameLabel + DescriptionLabel + LockLabel + SelectButton
- Lock system: `unlock_overrides: Dictionary` for test control, `_is_mode_unlocked()` checks overrides then defaults
- `update_lock_status()` sets button.disabled, lock_label.text, card.modulate.a (0.5 for locked)
- `_select_mode()` guards with `_is_mode_unlocked()`, clears config, sets mode, navigates to MapSelect
- Back button uses `SceneManager.go_to_main_menu()` (clears config + navigates)
- Navigation: ModeSelect -> MapSelect (`res://scenes/main/MapSelect.tscn`)
- XP thresholds stored as constants: DRAFT_XP_THRESHOLD=500, ENDLESS_XP_THRESHOLD=2000
- MetaProgression integration point: replace `_is_mode_unlocked()` stub when Task E1 is done

## MapSelect (Task A4)
- Root: Control with full-rect anchors, script `scripts/main/MapSelect.gd`
- 4 map cards in 2x2 GridContainer (columns=2): Forest, Mountain, River, Volcano
- Each card: PanelContainer > VBoxContainer > PreviewRect + NameLabel + DescriptionLabel + DifficultyLabel + LockLabel + SelectButton
- Preview thumbnails: ColorRect with distinct colors (green/gray/blue/red-orange)
- Difficulty: Unicode stars (filled + empty to 4 total)
- Lock system: same `unlock_overrides` pattern as ModeSelect
- `_select_map()` preserves existing config (mode), adds map key, calls `go_to_game(config)`
- Back button uses `SceneManager.change_scene(MODE_SELECT_PATH)` (preserves config, unlike ModeSelect back)
- Navigation: MapSelect -> Game (via go_to_game), MapSelect <- ModeSelect (back)
- XP thresholds: MOUNTAIN=1000, RIVER=3000, VOLCANO=6000
- Map scene paths: ForestClearing, MountainPass, RiverDelta, VolcanicCaldera in `res://scenes/maps/`

## Testing UI Scripts Without Scene Tree
- Build node tree manually in test helper (mirrors .tscn structure)
- Apply script via `set_script(load(path))`
- Manually assign `@onready` vars since `_ready()` won't be called
- Block SceneManager transitions by setting `is_transitioning = true`
- Track SceneManager calls via `scene_changing` signal + `_last_scene_path`
- Use `free()` in `after_test()` since menu nodes are not in the scene tree
