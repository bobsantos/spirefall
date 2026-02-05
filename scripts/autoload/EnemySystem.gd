class_name EnemySystemClass
extends Node

## Handles enemy spawning, object pooling, wave management.

signal enemy_spawned(enemy: Node)
signal enemy_killed(enemy: Node)
signal enemy_reached_exit(enemy: Node)
signal wave_cleared(wave_number: int)

var _enemy_scene: PackedScene = preload("res://scenes/enemies/BaseEnemy.tscn")
var _active_enemies: Array[Node] = []
var _wave_finished_spawning: bool = false
var _enemies_to_spawn: Array = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.5


func get_active_enemy_count() -> int:
	return _active_enemies.size()


func is_wave_finished() -> bool:
	return _wave_finished_spawning and _enemies_to_spawn.is_empty()


func get_active_enemies() -> Array[Node]:
	return _active_enemies


func spawn_wave(wave_number: int) -> void:
	_wave_finished_spawning = false
	_enemies_to_spawn = _build_wave_queue(wave_number)
	_spawn_timer = 0.0


func _process(delta: float) -> void:
	if _enemies_to_spawn.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_next_enemy()
		_spawn_timer = _spawn_interval


func _spawn_next_enemy() -> void:
	if _enemies_to_spawn.is_empty():
		_wave_finished_spawning = true
		return

	var enemy_data: EnemyData = _enemies_to_spawn.pop_front()
	var enemy: Node = _enemy_scene.instantiate()
	enemy.enemy_data = enemy_data
	enemy.path_points = PathfindingSystem.get_enemy_path()

	_active_enemies.append(enemy)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(enemy))
	enemy_spawned.emit(enemy)

	if _enemies_to_spawn.is_empty():
		_wave_finished_spawning = true


func on_enemy_killed(enemy: Node) -> void:
	EconomyManager.add_gold(enemy.enemy_data.gold_reward)
	enemy_killed.emit(enemy)
	_remove_enemy(enemy)
	enemy.queue_free()


func on_enemy_reached_exit(enemy: Node) -> void:
	GameManager.lose_life(1)
	enemy_reached_exit.emit(enemy)
	_remove_enemy(enemy)
	enemy.queue_free()


func _remove_enemy(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	if _active_enemies.is_empty() and _wave_finished_spawning:
		wave_cleared.emit(GameManager.current_wave)


func _on_enemy_removed(enemy: Node) -> void:
	_active_enemies.erase(enemy)


func _build_wave_queue(wave_number: int) -> Array:
	# Placeholder: spawn Normal enemies scaled by wave
	var queue: Array = []
	var count: int = 8 + int(wave_number / 3)
	for i: int in range(count):
		var data := EnemyData.new()
		data.enemy_name = "Normal"
		data.base_health = 100
		data.speed_multiplier = 1.0
		data.gold_reward = 3
		data.element = "none"
		# Apply scaling: HP = Base * (1 + 0.15 * wave)^2
		var scale_factor: float = (1.0 + 0.15 * wave_number) ** 2
		data.base_health = int(data.base_health * scale_factor)
		queue.append(data)
	return queue
