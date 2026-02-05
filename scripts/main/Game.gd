extends Node2D

## Main game scene. Orchestrates the game board, camera, input, and UI.

@onready var game_board: Node2D = $GameBoard
@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $Camera2D

var _placing_tower: TowerData = null
var _ghost_tower: Sprite2D = null

# Ghost tint colors: green = valid placement, red = invalid
const GHOST_COLOR_VALID := Color(0.2, 1.0, 0.2, 0.5)
const GHOST_COLOR_INVALID := Color(1.0, 0.2, 0.2, 0.5)


func _ready() -> void:
	UIManager.build_requested.connect(_on_build_requested)
	EnemySystem.enemy_spawned.connect(_on_enemy_spawned)
	TowerSystem.tower_created.connect(_on_tower_created)
	_load_map()
	GameManager.start_game()


func _load_map() -> void:
	var map_scene: PackedScene = load("res://scenes/maps/ForestClearing.tscn")
	var map_instance: Node2D = map_scene.instantiate()
	game_board.add_child(map_instance)


func _process(_delta: float) -> void:
	if _placing_tower:
		_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()

	if event.is_action_pressed("ui_cancel"):
		_cancel_placement()

	if event.is_action_pressed("ui_start_wave"):
		GameManager.start_wave_early()

	if event.is_action_pressed("ui_sell") and UIManager.selected_tower:
		TowerSystem.sell_tower(UIManager.selected_tower)
		UIManager.deselect_tower()

	if event.is_action_pressed("ui_upgrade") and UIManager.selected_tower:
		TowerSystem.upgrade_tower(UIManager.selected_tower)


func _handle_click(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = camera.get_global_mouse_position() if camera else get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(world_pos)

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
	_placing_tower = tower_data
	_create_ghost(tower_data)


func _on_enemy_spawned(enemy: Node) -> void:
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
	if tex:
		_ghost_tower.texture = tex
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


func _on_projectile_spawned(projectile: Node) -> void:
	game_board.add_child(projectile)
