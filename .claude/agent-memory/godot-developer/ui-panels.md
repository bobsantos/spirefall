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

## Testing UI Scripts Without Scene Tree
- Build node tree manually in test helper (mirrors .tscn structure)
- Apply script via `set_script(load(path))`
- Manually assign `@onready` vars since `_ready()` won't be called
- Block SceneManager transitions by setting `is_transitioning = true`
- Track SceneManager calls via `scene_changing` signal + `_last_scene_path`
- Use `free()` in `after_test()` since menu nodes are not in the scene tree
