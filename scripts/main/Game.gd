extends Node2D

## Main game scene. Orchestrates the game board, camera, input, and UI.
## Handles tower placement, fusion target selection, and scene-tree wiring.

@onready var game_board: Node2D = $GameBoard
@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $Camera2D

var _placing_tower: TowerData = null
var _ghost_tower: Sprite2D = null

# Fusion target selection state
var _fusing_tower: Node = null  # The tower that initiated fusion (stays in place)

# Ghost tint colors: green = valid placement, red = invalid
const GHOST_COLOR_VALID := Color(0.2, 1.0, 0.2, 0.5)
const GHOST_COLOR_INVALID := Color(1.0, 0.2, 0.2, 0.5)
# Fusion partner highlight color (pulsing yellow)
const FUSION_HIGHLIGHT_COLOR := Color(1.0, 0.9, 0.2, 1.0)

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


func _ready() -> void:
	UIManager.build_requested.connect(_on_build_requested)
	EnemySystem.enemy_spawned.connect(_on_enemy_spawned)
	EnemySystem.enemy_killed.connect(_on_enemy_killed)
	TowerSystem.tower_created.connect(_on_tower_created)
	TowerSystem.tower_sold.connect(_on_tower_sold)
	_load_map()
	GameManager.start_game()


func _load_map() -> void:
	var map_scene: PackedScene = load("res://scenes/maps/ForestClearing.tscn")
	var map_instance: Node2D = map_scene.instantiate()
	game_board.add_child(map_instance)


func _process(delta: float) -> void:
	_handle_camera_pan(delta)
	if _placing_tower:
		_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
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
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _fusing_tower:
				_cancel_fusion_selection()
			else:
				_cancel_placement()

	if event.is_action_pressed("ui_cancel"):
		if _fusing_tower:
			_cancel_fusion_selection()
		else:
			_cancel_placement()

	if event.is_action_pressed("ui_start_wave"):
		GameManager.start_wave_early()

	if event.is_action_pressed("ui_sell") and UIManager.selected_tower:
		TowerSystem.sell_tower(UIManager.selected_tower)
		UIManager.deselect_tower()

	if event.is_action_pressed("ui_upgrade") and UIManager.selected_tower:
		TowerSystem.upgrade_tower(UIManager.selected_tower)

	if event.is_action_pressed("ui_codex"):
		UIManager.toggle_codex()


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


func _handle_click(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = camera.get_global_mouse_position() if camera else get_global_mouse_position()
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
	else:
		# Try to select existing tower
		var tower: Node = GridManager.get_tower_at(grid_pos)
		if tower:
			UIManager.select_tower(tower)
		else:
			UIManager.deselect_tower()


func _on_build_requested(tower_data: TowerData) -> void:
	_cancel_fusion_selection()
	_placing_tower = tower_data
	_create_ghost(tower_data)


func _on_enemy_spawned(enemy: Node) -> void:
	# Connect boss ground effect signal (fire trail) so effects are added to the scene tree
	if enemy.has_signal("ground_effect_spawned"):
		enemy.ground_effect_spawned.connect(_on_ground_effect_spawned)
	game_board.add_child(enemy)


func _cancel_placement() -> void:
	_placing_tower = null
	_clear_ghost()


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

	var world_pos: Vector2 = camera.get_global_mouse_position() if camera else get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(world_pos)

	# Hide ghost if cursor is outside the grid
	if not GridManager.is_in_bounds(grid_pos):
		_ghost_tower.visible = false
		return

	_ghost_tower.visible = true
	# Snap ghost to cell center
	_ghost_tower.position = GridManager.grid_to_world(grid_pos)

	# Tint green if placement is valid, red if not
	if GridManager.can_place_tower(grid_pos) and EconomyManager.can_afford(_placing_tower.cost):
		_ghost_tower.modulate = GHOST_COLOR_VALID
	else:
		_ghost_tower.modulate = GHOST_COLOR_INVALID


func _clear_ghost() -> void:
	if _ghost_tower:
		_ghost_tower.queue_free()
		_ghost_tower = null


func _on_tower_created(tower: Node) -> void:
	if tower.has_signal("projectile_spawned"):
		tower.projectile_spawned.connect(_on_projectile_spawned)
	# Connect fuse_requested from the info panel once the panel exists
	_connect_tower_info_fuse_signal()


func _on_tower_sold(tower: Node, _refund: int) -> void:
	# If the sold tower was the fusion source, cancel fusion selection
	if _fusing_tower == tower:
		_cancel_fusion_selection()


func _on_projectile_spawned(projectile: Node) -> void:
	# Connect ground effect signal if the projectile can spawn ground effects
	if projectile.has_signal("ground_effect_spawned"):
		projectile.ground_effect_spawned.connect(_on_ground_effect_spawned)
	game_board.add_child(projectile)


func _on_ground_effect_spawned(effect: Node) -> void:
	game_board.add_child(effect)


func _on_enemy_killed(enemy: Node) -> void:
	var gold: int = enemy.enemy_data.gold_reward
	_spawn_gold_text(enemy.global_position, gold)


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
