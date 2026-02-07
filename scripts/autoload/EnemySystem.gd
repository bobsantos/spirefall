class_name EnemySystemClass
extends Node

## Handles enemy spawning, object pooling, wave management.

signal enemy_spawned(enemy: Node)
signal enemy_killed(enemy: Node)
signal enemy_reached_exit(enemy: Node)
signal wave_cleared(wave_number: int)

const WAVE_CONFIG_PATH: String = "res://resources/waves/wave_config.json"
const ENEMY_RESOURCE_DIR: String = "res://resources/enemies/"
const DEFAULT_SPAWN_INTERVAL: float = 0.5
const BOSS_SPAWN_INTERVAL: float = 1.5

var _enemy_scene: PackedScene = preload("res://scenes/enemies/BaseEnemy.tscn")
var _active_enemies: Array[Node] = []
var _wave_finished_spawning: bool = false
var _enemies_to_spawn: Array = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = DEFAULT_SPAWN_INTERVAL

# Parsed wave config: Dictionary keyed by wave number -> wave dict
var _wave_config: Dictionary = {}
# Cached base EnemyData resources keyed by type string (e.g. "normal", "fast")
var _enemy_templates: Dictionary = {}


func _ready() -> void:
	_load_wave_config()


func _load_wave_config() -> void:
	var file := FileAccess.open(WAVE_CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("EnemySystem: Failed to open wave config at %s" % WAVE_CONFIG_PATH)
		return
	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("EnemySystem: Failed to parse wave config JSON: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	if not data.has("waves"):
		push_error("EnemySystem: wave_config.json missing 'waves' array")
		return

	for wave_entry: Dictionary in data["waves"]:
		var wave_num: int = int(wave_entry["wave"])
		_wave_config[wave_num] = wave_entry


func _load_enemy_template(enemy_type: String) -> EnemyData:
	if _enemy_templates.has(enemy_type):
		return _enemy_templates[enemy_type]

	var path: String = ENEMY_RESOURCE_DIR + enemy_type + ".tres"
	var res: Resource = load(path)
	if res == null:
		push_error("EnemySystem: Could not load enemy resource at %s" % path)
		return null

	_enemy_templates[enemy_type] = res
	return res


func get_active_enemy_count() -> int:
	return _active_enemies.size()


func is_wave_finished() -> bool:
	return _wave_finished_spawning and _enemies_to_spawn.is_empty()


func get_active_enemies() -> Array[Node]:
	return _active_enemies


func get_wave_config(wave_number: int) -> Dictionary:
	## Returns the raw wave_config.json entry for the given wave number.
	## Empty dictionary if wave_number not found.
	if _wave_config.has(wave_number):
		return _wave_config[wave_number]
	return {}


func get_enemy_template(enemy_type: String) -> EnemyData:
	## Public accessor for enemy template data. Loads and caches on first access.
	return _load_enemy_template(enemy_type)


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
	if enemy_data.is_flying:
		enemy.path_points = PathfindingSystem.get_flying_path()
	else:
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
	GameManager.record_enemy_leak()
	enemy_reached_exit.emit(enemy)
	_remove_enemy(enemy)
	enemy.queue_free()


func spawn_split_enemies(parent: Node) -> void:
	## Spawn 2 child enemies at the parent's position, continuing from the parent's path index.
	## Called when a split enemy dies. Children are added to _active_enemies BEFORE the parent
	## is removed, so wave_cleared is not triggered prematurely.
	var split_data: EnemyData = parent.enemy_data.split_data
	if split_data == null:
		# No split data -- just do normal kill
		on_enemy_killed(parent)
		return

	var parent_path: PackedVector2Array = parent.path_points
	var parent_path_index: int = parent._path_index
	var parent_position: Vector2 = parent.position

	# Award gold for killing the parent
	EconomyManager.add_gold(parent.enemy_data.gold_reward)
	enemy_killed.emit(parent)

	# Spawn 2 children FIRST (add to _active_enemies before removing parent)
	for i: int in range(2):
		var child_data: EnemyData = _create_scaled_enemy(split_data, GameManager.current_wave)
		var child: Node = _enemy_scene.instantiate()
		child.enemy_data = child_data
		child.path_points = parent_path
		# Set path index and position so the child continues from where the parent died
		child._path_index = parent_path_index
		child.position = parent_position
		# Slight offset so children don't overlap perfectly
		if i == 0:
			child.position += Vector2(-8, 0)
		else:
			child.position += Vector2(8, 0)

		_active_enemies.append(child)
		child.tree_exiting.connect(_on_enemy_removed.bind(child))
		enemy_spawned.emit(child)

	# Now remove and free the parent (children are already in _active_enemies)
	_remove_enemy(parent)
	parent.queue_free()


func spawn_boss_minions(boss: Node, minion_template: EnemyData, count: int) -> void:
	## Spawn minions at the boss's position, continuing from the boss's path index.
	## Used by Glacial Wyrm and other bosses that summon adds mid-combat.
	if minion_template == null:
		return
	var boss_path: PackedVector2Array = boss.path_points
	var boss_path_index: int = boss._path_index
	var boss_position: Vector2 = boss.position

	for i: int in range(count):
		var data: EnemyData = _create_scaled_enemy(minion_template, GameManager.current_wave)
		var minion: Node = _enemy_scene.instantiate()
		minion.enemy_data = data
		if data.is_flying:
			minion.path_points = PathfindingSystem.get_flying_path()
		else:
			minion.path_points = boss_path
		minion._path_index = boss_path_index
		# Slight offset so minions don't stack perfectly
		minion.position = boss_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))

		_active_enemies.append(minion)
		minion.tree_exiting.connect(_on_enemy_removed.bind(minion))
		enemy_spawned.emit(minion)


func _remove_enemy(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	if _active_enemies.is_empty() and _wave_finished_spawning:
		wave_cleared.emit(GameManager.current_wave)


func _on_enemy_removed(enemy: Node) -> void:
	_active_enemies.erase(enemy)


func _build_wave_queue(wave_number: int) -> Array:
	if not _wave_config.has(wave_number):
		push_warning("EnemySystem: No config for wave %d, using fallback" % wave_number)
		return _build_fallback_queue(wave_number)

	var wave_entry: Dictionary = _wave_config[wave_number]
	var queue: Array = []

	# Set spawn interval: use config value if present, else slower for boss waves
	if wave_entry.has("spawn_interval"):
		_spawn_interval = float(wave_entry["spawn_interval"])
	elif wave_entry.get("is_boss_wave", false):
		_spawn_interval = BOSS_SPAWN_INTERVAL
	else:
		_spawn_interval = DEFAULT_SPAWN_INTERVAL

	var enemy_groups: Array = wave_entry["enemies"]
	for group: Dictionary in enemy_groups:
		var enemy_type: String = group["type"]
		var count: int = int(group["count"])

		var template: EnemyData = _load_enemy_template(enemy_type)
		if template == null:
			push_error("EnemySystem: Skipping unknown enemy type '%s'" % enemy_type)
			continue

		# Swarm enemies spawn spawn_count units per count entry
		var actual_count: int = count * template.spawn_count

		for i: int in range(actual_count):
			var data: EnemyData = _create_scaled_enemy(template, wave_number)
			queue.append(data)

	return queue


func _create_scaled_enemy(template: EnemyData, wave_number: int) -> EnemyData:
	var data := EnemyData.new()

	# Copy base fields from the template resource
	data.enemy_name = template.enemy_name
	data.element = template.element
	data.special = template.special
	data.is_flying = template.is_flying
	data.is_boss = template.is_boss
	data.spawn_count = template.spawn_count
	data.split_on_death = template.split_on_death
	data.split_data = template.split_data
	data.stealth = template.stealth
	data.heal_per_second = template.heal_per_second
	data.immune_element = template.immune_element
	data.weak_element = template.weak_element

	# Boss ability fields
	data.boss_ability_key = template.boss_ability_key
	data.boss_ability_interval = template.boss_ability_interval
	data.minion_data = template.minion_data
	data.minion_spawn_interval = template.minion_spawn_interval
	data.minion_spawn_count = template.minion_spawn_count

	# Apply GDD scaling formulas
	# HP = Base HP * (1 + 0.15 * wave)^2
	var hp_scale: float = (1.0 + 0.15 * wave_number) ** 2
	data.base_health = int(template.base_health * hp_scale)

	# Speed = Base * (1 + 0.02 * wave), capped at 2x base
	var speed_scale: float = minf(1.0 + 0.02 * wave_number, 2.0)
	data.speed_multiplier = template.speed_multiplier * speed_scale

	# Gold = Base Gold * (1 + 0.08 * wave)
	var gold_scale: float = 1.0 + 0.08 * wave_number
	data.gold_reward = int(template.gold_reward * gold_scale)

	return data


func _build_fallback_queue(wave_number: int) -> Array:
	## Generates a reasonable wave for wave numbers beyond the config.
	var queue: Array = []
	var template: EnemyData = _load_enemy_template("normal")
	if template == null:
		return queue

	var count: int = 8 + int(wave_number / 3)
	for i: int in range(count):
		var data: EnemyData = _create_scaled_enemy(template, wave_number)
		queue.append(data)

	_spawn_interval = DEFAULT_SPAWN_INTERVAL
	return queue
