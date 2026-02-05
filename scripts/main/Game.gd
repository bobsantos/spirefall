extends Node2D

## Main game scene. Orchestrates the game board, camera, input, and UI.

@onready var game_board: Node2D = $GameBoard
@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $Camera2D

var _placing_tower: TowerData = null
var _ghost_tower: Sprite2D = null


func _ready() -> void:
	UIManager.build_requested.connect(_on_build_requested)
	EnemySystem.enemy_spawned.connect(_on_enemy_spawned)
	_load_map()
	GameManager.start_game()


func _load_map() -> void:
	var map_scene: PackedScene = load("res://scenes/maps/ForestClearing.tscn")
	var map_instance: Node2D = map_scene.instantiate()
	game_board.add_child(map_instance)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)

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


func _on_enemy_spawned(enemy: Node) -> void:
	game_board.add_child(enemy)


func _cancel_placement() -> void:
	_placing_tower = null
	_clear_ghost()


func _clear_ghost() -> void:
	if _ghost_tower:
		_ghost_tower.queue_free()
		_ghost_tower = null
