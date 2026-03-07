extends Node2D

## Main game scene. Orchestrates the game board, camera, input, and UI.
## Handles tower placement, fusion target selection, and scene-tree wiring.

@onready var game_board: Node2D = $GameBoard
@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $Camera2D

var _build_fab: Button = null
var _cancel_fab: Button = null
var _placing_tower: TowerData = null
var _ghost_tower: Sprite2D = null
var _range_indicator: RangeIndicator = null

# Fusion target selection state
var _fusing_tower: Node = null  # The tower that initiated fusion (stays in place)

# --- Mobile placement auto-zoom state ---
var _pre_placement_zoom: Vector2 = Vector2.ZERO
var _placement_zoom_tween: Tween = null
var _snap_grid_pos: Vector2i = Vector2i(-1, -1)
var _cell_highlight: Node2D = null
var _auto_zoom_active: bool = false

# Ghost tint colors: green = valid placement, red = invalid
const GHOST_COLOR_VALID := Color(0.2, 1.0, 0.2, 0.5)
const GHOST_COLOR_INVALID := Color(1.0, 0.2, 0.2, 0.5)
# Fusion partner highlight color (pulsing yellow)
const FUSION_HIGHLIGHT_COLOR := Color(1.0, 0.9, 0.2, 1.0)

# --- Mobile placement auto-zoom constants ---
const SNAP_HYSTERESIS_THRESHOLD: float = 32.0  # half cell width
const PLACEMENT_ZOOM_DURATION: float = 0.3
const PLACEMENT_ZOOM_RESTORE_DELAY: float = 0.15
const CELL_HIGHLIGHT_VALID_COLOR := Color("#00CC66")
const CELL_HIGHLIGHT_INVALID_COLOR := Color("#CC3333")

# --- Camera pan/zoom constants ---
const PAN_SPEED: float = 400.0  # px/s at 1x zoom
const ZOOM_MIN: Vector2 = Vector2(0.5, 0.5)
const ZOOM_MAX: Vector2 = Vector2(2.0, 2.0)
const ZOOM_STEP: float = 0.1
# Map bounds for camera clamping (with padding so edges are visible when zoomed in)
const MAP_MIN: Vector2 = Vector2(0.0, 0.0)
const MAP_MAX: Vector2 = Vector2(1280.0, 960.0)

# Camera drag state
var _is_dragging: bool = false

# --- Touch input state ---
var _touches: Dictionary = {}  # finger_index -> Vector2 position
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_potential_tap: bool = false
var _is_long_pressing: bool = false
var _tap_processed: bool = false  # True once tap delay fires and tap is handled
var _initial_pinch_distance: float = 0.0
var _last_pinch_distance: float = 0.0
const TAP_DELAY: float = 0.15  # 150ms buffer to distinguish tap from pan gesture
const TAP_MOVE_THRESHOLD: float = 10.0  # px movement cancels tap
const LONG_PRESS_DURATION: float = 0.5  # 500ms triggers context action
const PINCH_ZOOM_SENSITIVITY: float = 0.005
var _last_touch_screen_pos: Vector2 = Vector2(-1.0, -1.0)  # Last single-finger position for ghost preview
var _placement_cooldown: int = 0  # Frame counter to prevent auto-select after placement (desktop)
var _placement_cooldown_time: float = 0.0  # Time-based cooldown for mobile (seconds)
var _synthetic_click_pending: bool = false  # Legacy flag (kept for compatibility, no longer used)

# --- Particle effect scenes ---
var _impact_effect_scene: PackedScene = preload("res://scenes/effects/particles/ImpactEffect.tscn")
var _death_effect_scene: PackedScene = preload("res://scenes/effects/particles/EnemyDeathEffect.tscn")
var _placement_effect_scene: PackedScene = preload("res://scenes/effects/particles/PlacementEffect.tscn")
var _upgrade_effect_scene: PackedScene = preload("res://scenes/effects/particles/UpgradeEffect.tscn")
var _shoot_effect_scene: PackedScene = preload("res://scenes/effects/particles/TowerShootEffect.tscn")


func _ready() -> void:
	UIManager.build_requested.connect(_on_build_requested)
	UIManager.placement_cancelled.connect(_cancel_placement)
	EnemySystem.enemy_spawned.connect(_on_enemy_spawned)
	EnemySystem.enemy_killed.connect(_on_enemy_killed)
	TowerSystem.tower_created.connect(_on_tower_created)
	TowerSystem.tower_sold.connect(_on_tower_sold)
	TowerSystem.tower_upgraded.connect(_on_tower_upgraded)
	TowerSystem.fusion_failed.connect(_on_fusion_failed)
	UIManager.tower_selected.connect(_on_tower_selected_for_range)
	UIManager.tower_deselected.connect(_on_tower_deselected_for_range)
	_range_indicator = RangeIndicator.new()
	game_board.add_child(_range_indicator)
	_load_map()
	_start_game_from_config()
	if UIManager.is_mobile():
		_create_build_fab()
		_create_cancel_fab()


func _load_map() -> void:
	var map_path: String = SceneManager.current_game_config.get("map", "res://scenes/maps/ForestClearing.tscn")
	var map_scene: PackedScene = load(map_path)
	var map_instance: Node2D = map_scene.instantiate()
	game_board.add_child(map_instance)


func _start_game_from_config() -> void:
	var mode: String = SceneManager.current_game_config.get("mode", "classic")
	GameManager.start_game(mode)


func _create_build_fab() -> void:
	## Create a floating action button in the bottom-right to toggle the build menu.
	_build_fab = Button.new()
	_build_fab.text = "Build"
	_build_fab.custom_minimum_size = Vector2(128, 128)
	_build_fab.size = Vector2(128, 128)
	_build_fab.focus_mode = Control.FOCUS_NONE

	# Gold circular style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color("#FFD700")
	style_normal.set_corner_radius_all(64)
	style_normal.set_content_margin_all(8)
	_build_fab.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	_build_fab.add_theme_stylebox_override("hover", style_hover)

	# Pressed style: darkened 20%
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color("#CCB000")
	style_pressed.set_corner_radius_all(64)
	style_pressed.set_content_margin_all(8)
	_build_fab.add_theme_stylebox_override("pressed", style_pressed)

	_build_fab.add_theme_color_override("font_color", Color(0.15, 0.1, 0.0))
	_build_fab.add_theme_font_size_override("font_size", 20)

	# Add to tree FIRST, then set anchors (anchors need parent size to resolve)
	ui_layer.add_child(_build_fab)

	# Position: bottom-right, 16px margin from edges
	_build_fab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_build_fab.offset_left = -128 - 16
	_build_fab.offset_top = -128 - 16
	_build_fab.offset_right = -16
	_build_fab.offset_bottom = -16

	_build_fab.pressed.connect(_on_build_fab_pressed)
	GameManager.phase_changed.connect(_on_fab_phase_changed)
	UIManager.build_requested.connect(_on_fab_build_requested)
	UIManager.placement_ended.connect(_on_fab_placement_ended)


func _create_cancel_fab() -> void:
	## Create a floating cancel button shown during placement mode on mobile.
	_cancel_fab = Button.new()
	_cancel_fab.text = "Cancel"
	_cancel_fab.custom_minimum_size = Vector2(128, 128)
	_cancel_fab.size = Vector2(128, 128)
	_cancel_fab.focus_mode = Control.FOCUS_NONE

	# Red circular style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color("#CC3333")
	style_normal.set_corner_radius_all(64)
	style_normal.set_content_margin_all(8)
	_cancel_fab.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	_cancel_fab.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color("#992222")
	style_pressed.set_corner_radius_all(64)
	style_pressed.set_content_margin_all(8)
	_cancel_fab.add_theme_stylebox_override("pressed", style_pressed)

	_cancel_fab.add_theme_color_override("font_color", Color.WHITE)
	_cancel_fab.add_theme_font_size_override("font_size", 20)

	ui_layer.add_child(_cancel_fab)

	# Position: bottom-right (same position as Build FAB)
	_cancel_fab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cancel_fab.offset_left = -128 - 16
	_cancel_fab.offset_top = -128 - 16
	_cancel_fab.offset_right = -16
	_cancel_fab.offset_bottom = -16

	_cancel_fab.pressed.connect(_on_cancel_fab_pressed)
	_cancel_fab.visible = false


func _on_cancel_fab_pressed() -> void:
	_cancel_placement()


func _on_build_fab_pressed() -> void:
	## Toggle the build menu bottom sheet.
	_toggle_build_sheet()


func _toggle_build_sheet() -> void:
	if UIManager.build_menu:
		if UIManager.build_menu._is_sheet_visible:
			UIManager.build_menu.slide_out()
		else:
			UIManager.build_menu.slide_in()


func _on_fab_phase_changed(_new_phase: GameManagerClass.GameState) -> void:
	## Keep FAB visible in all phases so players can build during combat.
	pass


func _on_fab_build_requested(_tower_data: TowerData) -> void:
	## Hide FAB and show cancel FAB while in placement mode.
	if _build_fab:
		_build_fab.visible = false
	if _cancel_fab:
		_cancel_fab.visible = true


func _on_fab_placement_ended() -> void:
	## Restore FAB after placement ends, hide cancel FAB.
	if _build_fab:
		_build_fab.visible = true
	if _cancel_fab:
		_cancel_fab.visible = false


func _process(delta: float) -> void:
	_handle_camera_pan(delta)
	_handle_touch_timers(delta)
	if _placement_cooldown > 0:
		_placement_cooldown -= 1
	if _placement_cooldown_time > 0.0:
		_placement_cooldown_time -= delta
	if _placing_tower:
		_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	# --- Touch input ---
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return

	# --- Camera: middle mouse drag ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			get_viewport().set_input_as_handled()
			return
		# --- Camera: scroll wheel zoom ---
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(ZOOM_STEP, event.position)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(-ZOOM_STEP, event.position)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and _is_dragging:
		# Invert relative motion and scale by zoom for natural drag feel
		camera.position -= event.relative / camera.zoom
		_clamp_camera()
		get_viewport().set_input_as_handled()
		return

	# --- Non-camera input below ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Legacy guard: _synthetic_click_pending is no longer set (direct
			# action invocation replaced synthetic mouse injection) but kept
			# for safety in case any code path still sets it.
			if _synthetic_click_pending:
				_synthetic_click_pending = false
				return
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _fusing_tower:
				_cancel_fusion_selection()
			else:
				_cancel_placement()

	if event.is_action_pressed("ui_cancel"):
		if _fusing_tower:
			_cancel_fusion_selection()
		elif _placing_tower:
			_cancel_placement()
		else:
			# No active placement or fusion: toggle pause
			GameManager.toggle_pause()

	if event.is_action_pressed("ui_start_wave"):
		GameManager.start_wave_early()

	if event.is_action_pressed("ui_sell") and UIManager.selected_tower:
		TowerSystem.sell_tower(UIManager.selected_tower)
		UIManager.deselect_tower()

	if event.is_action_pressed("ui_upgrade") and UIManager.selected_tower:
		TowerSystem.upgrade_tower(UIManager.selected_tower)

	if event.is_action_pressed("ui_codex"):
		UIManager.toggle_codex()

	if event.is_action_pressed("ui_fuse") and UIManager.selected_tower:
		_on_fuse_requested(UIManager.selected_tower)

	# Number keys 1-6: select tower from build menu
	for i: int in range(6):
		if event.is_action_pressed("ui_build_%d" % (i + 1)):
			_build_tower_by_index(i)
			break


# --- Camera helper methods ---

func _handle_camera_pan(delta: float) -> void:
	var pan_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_pan_left"):
		pan_dir.x -= 1.0
	if Input.is_action_pressed("ui_pan_right"):
		pan_dir.x += 1.0
	if Input.is_action_pressed("ui_pan_up"):
		pan_dir.y -= 1.0
	if Input.is_action_pressed("ui_pan_down"):
		pan_dir.y += 1.0

	if pan_dir != Vector2.ZERO:
		# Scale pan speed inversely with zoom so it feels consistent
		var effective_speed: float = PAN_SPEED / camera.zoom.x
		camera.position += pan_dir.normalized() * effective_speed * delta
		_clamp_camera()


func _zoom_camera(step: float, screen_pos: Vector2) -> void:
	# Zoom toward/away from mouse position (keeps world point under cursor fixed)
	var old_zoom: Vector2 = camera.zoom
	var new_zoom_val: float = clampf(old_zoom.x + step, ZOOM_MIN.x, ZOOM_MAX.x)
	var new_zoom := Vector2(new_zoom_val, new_zoom_val)

	if new_zoom == old_zoom:
		return

	# World position under mouse before zoom change
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_offset: Vector2 = screen_pos - viewport_size * 0.5
	var world_mouse_before: Vector2 = camera.position + mouse_offset / old_zoom

	# Apply new zoom
	camera.zoom = new_zoom

	# Adjust position so the same world point stays under the cursor
	var world_mouse_after: Vector2 = camera.position + mouse_offset / new_zoom
	camera.position += world_mouse_before - world_mouse_after
	_clamp_camera()


func _clamp_camera() -> void:
	# Clamp camera so the visible area doesn't go too far beyond the map edges.
	# The visible half-size depends on zoom level.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var half_view: Vector2 = viewport_size * 0.5 / camera.zoom
	# Allow the camera center to range so the map edge is at screen edge, with a small margin
	var margin: float = 64.0
	var min_pos: Vector2 = MAP_MIN + half_view - Vector2(margin, margin)
	var max_pos: Vector2 = MAP_MAX - half_view + Vector2(margin, margin)
	# If the view is larger than the map (zoomed out far), center the camera
	if min_pos.x > max_pos.x:
		camera.position.x = (MAP_MIN.x + MAP_MAX.x) * 0.5
	else:
		camera.position.x = clampf(camera.position.x, min_pos.x, max_pos.x)
	if min_pos.y > max_pos.y:
		camera.position.y = (MAP_MIN.y + MAP_MAX.y) * 0.5
	else:
		camera.position.y = clampf(camera.position.y, min_pos.y, max_pos.y)


# --- Touch input handlers ---

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			# First finger down: start potential tap
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
			_is_potential_tap = true
			_is_long_pressing = false
			_tap_processed = false
			_last_touch_screen_pos = event.position
		elif _touches.size() == 2:
			# Second finger: cancel tap, start pinch/pan tracking
			_is_potential_tap = false
			_is_long_pressing = false
			var positions: Array = _touches.values()
			_initial_pinch_distance = (positions[0] as Vector2).distance_to(positions[1] as Vector2)
			_last_pinch_distance = _initial_pinch_distance
	else:
		# Finger released
		var was_potential_tap: bool = _is_potential_tap and not _tap_processed
		var tap_screen_pos: Vector2 = _touch_start_pos
		_touches.erase(event.index)
		if was_potential_tap and _touches.is_empty():
			# Single finger released quickly without moving: process as tap
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - _touch_start_time
			if elapsed < LONG_PRESS_DURATION:
				# Check if tap is over a GUI control; if so, forward as a
				# synthetic mouse click so Godot's GUI system activates the
				# button.  This is necessary on mobile-web where
				# emulate_mouse_from_touch may not generate usable mouse
				# events (touch-action:none suppresses browser-synthesized
				# mouse events, and Godot's own emulation is unreliable on
				# HTML5).
				if not _try_forward_touch_to_gui(tap_screen_pos):
					_handle_click(tap_screen_pos)
			_is_potential_tap = false
		if _touches.is_empty():
			_is_potential_tap = false
			_is_long_pressing = false
			_tap_processed = false
			_last_touch_screen_pos = Vector2(-1.0, -1.0)
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _try_forward_touch_to_gui(screen_pos: Vector2) -> bool:
	## Check whether screen_pos hits a visible GUI control that should receive
	## the tap.  If it does, directly invoke the control's action and return
	## true.  Otherwise return false so the caller can process the tap as a
	## game-grid click.
	##
	## Why direct invocation instead of synthetic mouse events?
	## On Godot 4.x web exports, InputEventScreenTouch is never routed through
	## GUI hit-testing.  Synthetic InputEventMouseButton injection via
	## Input.parse_input_event() also fails on mobile-web because the browser's
	## touch-action:none suppresses mouse event synthesis and Godot's own
	## emulation is unreliable.  By directly calling the button's action (or
	## emitting its pressed signal) we bypass Godot's GUI input pipeline
	## entirely and guarantee the button fires on every platform.
	var vp: Viewport = get_viewport()
	if vp == null:
		return false

	# --- Build FAB ---
	if _build_fab and _build_fab.visible:
		if _control_hit_test(_build_fab, screen_pos):
			_toggle_build_sheet()
			return true

	# --- Cancel FAB (shown during placement mode on mobile) ---
	if _cancel_fab and _cancel_fab.visible:
		if _control_hit_test(_cancel_fab, screen_pos):
			_cancel_placement()
			return true

	# --- HUD buttons ---
	if UIManager.hud:
		var hud_node: Control = UIManager.hud

		# All HUD buttons: speed, pause (mobile), start-wave.
		for child_name: String in ["TopBar/SpeedButton", "TopBar/MobilePauseButton", "WaveControls/StartWaveButton"]:
			var ctrl: Control = hud_node.get_node_or_null(child_name)
			if ctrl and ctrl.visible and ctrl is Button and _control_hit_test(ctrl, screen_pos):
				(ctrl as Button).pressed.emit()
				return true

	# --- Build-menu buttons (sheet mode, visible when slid in) ---
	if UIManager.build_menu and UIManager.build_menu.visible:
		var hit_btn: Button = _find_hit_button(UIManager.build_menu, screen_pos)
		if hit_btn:
			hit_btn.pressed.emit()
			return true
		# Tap landed on the build menu panel itself (not a button) -- still
		# consume the tap so it doesn't register as a grid click.
		if _control_hit_test(UIManager.build_menu, screen_pos):
			return true

	# --- Tower info panel buttons (sell, upgrade, fuse) ---
	if UIManager.tower_info_panel and UIManager.tower_info_panel.visible:
		var hit_btn: Button = _find_hit_button(UIManager.tower_info_panel, screen_pos)
		if hit_btn:
			hit_btn.pressed.emit()
			return true
		if _control_hit_test(UIManager.tower_info_panel, screen_pos):
			return true

	return false


func _control_hit_test(ctrl: Control, screen_pos: Vector2) -> bool:
	## Return true if screen_pos falls within the control's visible rect.
	## Accounts for CanvasLayer transforms, anchors, and viewport stretch.
	if not ctrl.is_inside_tree() or not ctrl.visible:
		return false
	var local_pos: Vector2 = ctrl.get_global_transform_with_canvas().affine_inverse() * screen_pos
	return Rect2(Vector2.ZERO, ctrl.size).has_point(local_pos)


func _find_hit_button(root: Control, screen_pos: Vector2) -> Button:
	## Recursively search root's children for the first visible Button whose
	## rect contains screen_pos.  Returns null if no button is hit.
	for child: Node in root.get_children():
		if child is Button and child.visible and not (child as Button).disabled:
			if _control_hit_test(child as Control, screen_pos):
				return child as Button
		elif child is Control and child.visible:
			var found: Button = _find_hit_button(child as Control, screen_pos)
			if found:
				return found
	return null


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	# Check if single-finger movement exceeds tap threshold
	if _is_potential_tap and _touches.size() == 1:
		var moved: float = event.position.distance_to(_touch_start_pos)
		if moved > TAP_MOVE_THRESHOLD:
			_is_potential_tap = false
			_is_long_pressing = false

	# Update ghost tower preview position during single-finger drag in placement mode
	if _touches.size() == 1 and _placing_tower:
		_last_touch_screen_pos = event.position

	# Two-finger gestures: camera pan and pinch zoom
	if _touches.size() == 2:
		# If player pinch-zooms during placement, cancel auto-zoom and restore manual control
		if _placing_tower and _auto_zoom_active:
			if _placement_zoom_tween and _placement_zoom_tween.is_valid():
				_placement_zoom_tween.kill()
			_auto_zoom_active = false
			if _ghost_tower:
				_ghost_tower.scale = Vector2(1.5, 1.5)

		var keys: Array = _touches.keys()
		var pos_a: Vector2 = _touches[keys[0]]
		var pos_b: Vector2 = _touches[keys[1]]

		# Pan: apply average drag delta (use the current finger's relative motion)
		var pan_delta: Vector2 = event.relative / camera.zoom
		camera.position -= pan_delta
		_clamp_camera()

		# Pinch zoom: compare finger distance to last known distance
		var current_distance: float = pos_a.distance_to(pos_b)
		if _last_pinch_distance > 0.0:
			var distance_delta: float = current_distance - _last_pinch_distance
			var zoom_step: float = distance_delta * PINCH_ZOOM_SENSITIVITY
			if absf(zoom_step) > 0.001:
				var pinch_center: Vector2 = (pos_a + pos_b) * 0.5
				_zoom_camera(zoom_step, pinch_center)
		_last_pinch_distance = current_distance

	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _handle_touch_timers(delta: float) -> void:
	if not _is_potential_tap:
		return
	if _tap_processed:
		return

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _touch_start_time

	# Tap delay: if 150ms elapsed with still just one finger, process the tap
	# (We defer actual tap processing to finger release for a better feel,
	# but we use the delay window to reject multi-finger gestures.)

	# Long press detection: held > 0.5s without moving = context action
	if elapsed >= LONG_PRESS_DURATION and not _is_long_pressing and _touches.size() == 1:
		_is_long_pressing = true
		_tap_processed = true
		_is_potential_tap = false
		Input.vibrate_handheld(50)
		# Long press acts as right-click: cancel fusion or placement
		if _fusing_tower:
			_cancel_fusion_selection()
		elif _placing_tower:
			_cancel_placement()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	## Convert a screen-space position to world-space using the canvas transform.
	## This accounts for viewport stretch, camera position, and zoom correctly
	## across all platforms (desktop, web, mobile).
	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos


func _handle_click(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(screen_pos)
	var grid_pos: Vector2i = GridManager.world_to_grid(world_pos)

	# Fusion target selection mode: clicking a tower tries to fuse
	if _fusing_tower:
		_handle_fusion_click(grid_pos)
		return

	if _placing_tower:
		var tower: Node = TowerSystem.create_tower(_placing_tower, grid_pos)
		if tower:
			game_board.add_child(tower)
			_placing_tower = null
			_clear_ghost()
			_restore_placement_zoom()
			# Prevent auto-selecting the just-placed tower from emulated mouse events.
			# Mobile needs a longer time-based cooldown (~0.3s) because
			# emulate_mouse_from_touch generates delayed clicks after the touch.
			if UIManager.is_mobile():
				_placement_cooldown_time = 0.3
			else:
				_placement_cooldown = 2
			UIManager.placement_ended.emit()
	elif _placement_cooldown <= 0 and _placement_cooldown_time <= 0.0:
		# Try to select existing tower
		var tower: Node = GridManager.get_tower_at(grid_pos)
		if tower:
			UIManager.select_tower(tower)
		else:
			UIManager.deselect_tower()


func _build_tower_by_index(index: int) -> void:
	## Keyboard shortcut handler: request building the tower at the given index
	## in the build menu (0-based). Does nothing if no build menu or index invalid.
	if UIManager.build_menu and UIManager.build_menu.has_method("get_tower_data_by_index"):
		var tower_data: TowerData = UIManager.build_menu.get_tower_data_by_index(index)
		if tower_data:
			UIManager.request_build(tower_data)


func _on_build_requested(tower_data: TowerData) -> void:
	_cancel_fusion_selection()
	_placing_tower = tower_data
	_create_ghost(tower_data)
	if UIManager.is_mobile():
		# Mobile: no auto-zoom -- keep the full board visible so the player
		# can decide where to place.  Ghost stays at the default 1.5x scale.
		_auto_zoom_active = false
		_snap_grid_pos = Vector2i(-1, -1)
		_create_cell_highlight()


func _on_enemy_spawned(enemy: Node) -> void:
	# Connect boss ground effect signal (fire trail) so effects are added to the scene tree
	if enemy.has_signal("ground_effect_spawned"):
		enemy.ground_effect_spawned.connect(_on_ground_effect_spawned)
	game_board.add_child(enemy)


func _cancel_placement() -> void:
	_placing_tower = null
	_clear_ghost()
	_restore_placement_zoom()
	UIManager.placement_ended.emit()


func _create_ghost(tower_data: TowerData) -> void:
	_clear_ghost()
	_ghost_tower = Sprite2D.new()
	# Load the tower sprite texture using the same naming convention as Tower.gd
	var texture_name: String = tower_data.tower_name.to_lower().replace(" ", "_")
	var texture_path: String = "res://assets/sprites/towers/%s.png" % texture_name
	var tex: Texture2D = load(texture_path)
	if tex == null:
		# Fallback: strip "_enhanced" or "_superior" suffix to find base sprite
		texture_name = texture_name.replace("_enhanced", "").replace("_superior", "")
		texture_path = "res://assets/sprites/towers/%s.png" % texture_name
		tex = load(texture_path)
	if tex:
		_ghost_tower.texture = tex
	_ghost_tower.scale = Vector2(1.5, 1.5)
	_ghost_tower.modulate = GHOST_COLOR_VALID
	_ghost_tower.z_index = 100  # Render above towers and enemies
	_ghost_tower.visible = false  # Hidden until first _update_ghost positions it
	game_board.add_child(_ghost_tower)


func _update_ghost() -> void:
	if not _ghost_tower:
		return

	# Use last touch position if available, otherwise fall back to mouse position
	var world_pos: Vector2
	if _last_touch_screen_pos.x >= 0.0:
		world_pos = _screen_to_world(_last_touch_screen_pos)
	elif camera:
		world_pos = camera.get_global_mouse_position()
	else:
		world_pos = get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(world_pos)

	# Mobile hysteresis: only change snapped cell if finger moves far enough from current cell center
	if UIManager.is_mobile() and _snap_grid_pos != Vector2i(-1, -1):
		var snap_center: Vector2 = GridManager.grid_to_world(_snap_grid_pos)
		var dist: float = world_pos.distance_to(snap_center)
		if dist <= SNAP_HYSTERESIS_THRESHOLD:
			grid_pos = _snap_grid_pos
		else:
			_snap_grid_pos = grid_pos
	else:
		_snap_grid_pos = grid_pos

	# Hide ghost if cursor is outside the grid
	if not GridManager.is_in_bounds(grid_pos):
		_ghost_tower.visible = false
		if _range_indicator:
			_range_indicator.hide_range()
		_clear_cell_highlight()
		return

	_ghost_tower.visible = true
	# Snap ghost to cell center
	var cell_center: Vector2 = GridManager.grid_to_world(grid_pos)
	_ghost_tower.position = cell_center

	# Tint green if placement is valid, red if not
	var is_valid: bool = GridManager.can_place_tower(grid_pos) and EconomyManager.can_afford(_placing_tower.cost)
	if is_valid:
		_ghost_tower.modulate = GHOST_COLOR_VALID
		if _range_indicator:
			_range_indicator.show_range_for_tower(cell_center, _placing_tower)
	else:
		_ghost_tower.modulate = GHOST_COLOR_INVALID
		if _range_indicator:
			_range_indicator.hide_range()

	# Update cell highlight overlay on mobile
	if UIManager.is_mobile():
		_update_cell_highlight(grid_pos, is_valid)


func _clear_ghost() -> void:
	if _ghost_tower:
		_ghost_tower.queue_free()
		_ghost_tower = null
	if _range_indicator:
		_range_indicator.hide_range()


func _on_tower_created(tower: Node) -> void:
	if tower.has_signal("projectile_spawned"):
		tower.projectile_spawned.connect(_on_projectile_spawned)
	# Connect fuse_requested from the info panel once the panel exists
	_connect_tower_info_fuse_signal()
	# Placement dust poof
	_spawn_effect(_placement_effect_scene, tower.position)


func _on_tower_upgraded(tower: Node) -> void:
	# Sparkle effect on upgrade
	var color: Color = Color(1.0, 0.85, 0.2, 1.0)  # Gold
	_spawn_effect(_upgrade_effect_scene, tower.position, color)


func _on_tower_sold(tower: Node, _refund: int) -> void:
	# If the sold tower was the fusion source, cancel fusion selection
	if _fusing_tower == tower:
		_cancel_fusion_selection()


func _on_fusion_failed(tower: Node, reason: String) -> void:
	if not is_instance_valid(tower):
		return
	var label: Label = FusionErrorPopup.spawn(reason, tower.global_position)
	game_board.add_child(label)
	FusionErrorPopup.animate(label)


func _on_projectile_spawned(projectile: Node) -> void:
	# Connect ground effect signal if the projectile can spawn ground effects
	if projectile.has_signal("ground_effect_spawned"):
		projectile.ground_effect_spawned.connect(_on_ground_effect_spawned)
	# Connect impact signal for particle effects
	if projectile.has_signal("impact"):
		projectile.impact.connect(_on_projectile_impact)
	# Spawn tower shoot effect at the projectile's origin (tower position)
	if projectile is Projectile:
		var elem_color: Color = ElementMatrix.get_color(projectile.element)
		_spawn_effect(_shoot_effect_scene, projectile.global_position, elem_color)
	game_board.add_child(projectile)


func _on_ground_effect_spawned(effect: Node) -> void:
	game_board.add_child(effect)


func _on_projectile_impact(pos: Vector2, elem_color: Color) -> void:
	_spawn_effect(_impact_effect_scene, pos, elem_color)


func _spawn_effect(scene: PackedScene, pos: Vector2, color: Color = Color.WHITE) -> void:
	## Instantiate a ParticleEffect scene, spawn it at pos with color, and add to game_board.
	if scene == null:
		return
	var effect: Node = scene.instantiate()
	game_board.add_child(effect)
	if effect.has_method("spawn"):
		effect.spawn(pos, color)


func _on_enemy_killed(enemy: Node) -> void:
	var gold: int = enemy.enemy_data.gold_reward
	_spawn_gold_text(enemy.global_position, gold)
	_spawn_effect(_death_effect_scene, enemy.global_position)


func _spawn_gold_text(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+%dg" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = pos - Vector2(20, 10)
	label.z_index = 50
	game_board.add_child(label)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


# --- Mobile placement auto-zoom helpers ---

func _restore_placement_zoom() -> void:
	if not UIManager.is_mobile():
		return
	# No zoom tween to restore since mobile no longer auto-zooms.
	# Just clean up placement-mode state.
	_auto_zoom_active = false
	_snap_grid_pos = Vector2i(-1, -1)
	_clear_cell_highlight()
	if _placement_zoom_tween and _placement_zoom_tween.is_valid():
		_placement_zoom_tween.kill()
	if _ghost_tower:
		_ghost_tower.scale = Vector2(1.5, 1.5)


func _create_cell_highlight() -> void:
	if _cell_highlight:
		return
	_cell_highlight = Node2D.new()
	_cell_highlight.z_index = 99
	_cell_highlight.visible = false
	_cell_highlight.set_script(load("res://scripts/ui/CellHighlight.gd"))
	game_board.add_child(_cell_highlight)


func _update_cell_highlight(grid_pos: Vector2i, is_valid: bool) -> void:
	if not _cell_highlight:
		return
	var cell_center: Vector2 = GridManager.grid_to_world(grid_pos)
	_cell_highlight.position = cell_center
	_cell_highlight.set_meta("is_valid", is_valid)
	_cell_highlight.visible = true
	_cell_highlight.queue_redraw()


func _clear_cell_highlight() -> void:
	if _cell_highlight:
		_cell_highlight.visible = false


# --- Range indicator for tower selection ---

func _on_tower_selected_for_range(tower: Node) -> void:
	if _range_indicator and tower and is_instance_valid(tower) and tower.tower_data:
		_range_indicator.show_range_for_tower(tower.position, tower.tower_data)


func _on_tower_deselected_for_range() -> void:
	if _range_indicator:
		_range_indicator.hide_range()


# --- Fusion target selection flow ---

var _fuse_signal_connected: bool = false


func _connect_tower_info_fuse_signal() -> void:
	## Connect the TowerInfoPanel's fuse_requested signal exactly once.
	if _fuse_signal_connected:
		return
	if UIManager.tower_info_panel and UIManager.tower_info_panel.has_signal("fuse_requested"):
		UIManager.tower_info_panel.fuse_requested.connect(_on_fuse_requested)
		_fuse_signal_connected = true


func _on_fuse_requested(tower: Node) -> void:
	## Enter fusion target selection mode. Player must click a valid partner tower.
	_cancel_placement()
	_fusing_tower = tower
	UIManager.deselect_tower()
	_highlight_fusion_partners(tower)


func _handle_fusion_click(grid_pos: Vector2i) -> void:
	## During fusion selection, clicking a tower attempts to fuse it with _fusing_tower.
	var target: Node = GridManager.get_tower_at(grid_pos)
	if not target or target == _fusing_tower:
		_cancel_fusion_selection()
		return

	var fused: bool = false
	# Try dual fusion (both tier 1 Superior)
	if FusionRegistry.can_fuse(_fusing_tower, target):
		fused = TowerSystem.fuse_towers(_fusing_tower, target)
	# Try legendary: _fusing_tower as tier2 + target as superior
	elif FusionRegistry.can_fuse_legendary(_fusing_tower, target):
		fused = TowerSystem.fuse_legendary(_fusing_tower, target)
	# Try legendary: target as tier2 + _fusing_tower as superior
	elif FusionRegistry.can_fuse_legendary(target, _fusing_tower):
		fused = TowerSystem.fuse_legendary(target, _fusing_tower)

	_clear_fusion_highlights()
	if fused:
		# Select the resulting fused tower to show its new stats
		var result_tower: Node = _fusing_tower
		# For the reversed legendary case, the result is `target` since it was tier2
		if not is_instance_valid(_fusing_tower) and is_instance_valid(target):
			result_tower = target
		_fusing_tower = null
		if is_instance_valid(result_tower):
			UIManager.select_tower(result_tower)
	else:
		_fusing_tower = null


func _cancel_fusion_selection() -> void:
	_fusing_tower = null
	_clear_fusion_highlights()


func _highlight_fusion_partners(tower: Node) -> void:
	## Visually highlight all valid fusion partner towers with a pulsing tint.
	var partners: Array[Node] = []
	# Collect dual fusion partners
	var dual: Array[Node] = FusionRegistry.get_fusion_partners(tower)
	for p: Node in dual:
		if p not in partners:
			partners.append(p)
	# Collect legendary fusion partners
	var legendary: Array[Node] = FusionRegistry.get_legendary_partners(tower)
	for p: Node in legendary:
		if p not in partners:
			partners.append(p)

	for partner: Node in partners:
		if is_instance_valid(partner) and partner.has_node("Sprite2D"):
			var spr: Sprite2D = partner.get_node("Sprite2D")
			# Store original modulate so we can restore it
			spr.set_meta("_pre_fuse_modulate", spr.modulate)
			# Pulse the highlight using a looping tween
			var tw: Tween = partner.create_tween().set_loops()
			tw.tween_property(spr, "modulate", FUSION_HIGHLIGHT_COLOR, 0.4)
			tw.tween_property(spr, "modulate", Color.WHITE, 0.4)
			spr.set_meta("_fuse_tween", tw)


func _clear_fusion_highlights() -> void:
	## Remove all fusion partner highlights and restore original modulates.
	for tower: Node in TowerSystem.get_active_towers():
		if not is_instance_valid(tower) or not tower.has_node("Sprite2D"):
			continue
		var spr: Sprite2D = tower.get_node("Sprite2D")
		if spr.has_meta("_fuse_tween"):
			var tw: Tween = spr.get_meta("_fuse_tween")
			if tw and tw.is_valid():
				tw.kill()
			spr.remove_meta("_fuse_tween")
		if spr.has_meta("_pre_fuse_modulate"):
			spr.modulate = spr.get_meta("_pre_fuse_modulate")
			spr.remove_meta("_pre_fuse_modulate")
