extends Area2D

## Base tower script. Handles targeting, attacking via projectiles, and upgrades.

signal projectile_spawned(projectile: Node)

enum TargetMode { FIRST, LAST, STRONGEST, WEAKEST, CLOSEST }

@export var tower_data: TowerData
var grid_position: Vector2i = Vector2i.ZERO
var target_mode: TargetMode = TargetMode.FIRST
var _current_target: Node = null
var _attack_timer: float = 0.0
var _range_pixels: float = 0.0

var _projectile_scene: PackedScene = preload("res://scenes/projectiles/BaseProjectile.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var attack_cooldown: Timer = $AttackCooldown


func _ready() -> void:
	if tower_data:
		apply_tower_data()


func apply_tower_data() -> void:
	_range_pixels = tower_data.range_cells * GridManager.CELL_SIZE
	# Update collision shape to match range
	var shape := CircleShape2D.new()
	shape.radius = _range_pixels
	collision.shape = shape
	# Set attack cooldown
	attack_cooldown.wait_time = 1.0 / tower_data.attack_speed
	attack_cooldown.one_shot = false
	# Load tower sprite texture from name (e.g. "Flame Spire" -> "flame_spire")
	var texture_name: String = tower_data.tower_name.to_lower().replace(" ", "_")
	var texture_path: String = "res://assets/sprites/towers/%s.png" % texture_name
	sprite.texture = load(texture_path)


func _process(_delta: float) -> void:
	if GameManager.game_state != GameManager.GameState.COMBAT_PHASE:
		return
	_current_target = _find_target()
	if _current_target and attack_cooldown.is_stopped():
		_attack(_current_target)
		attack_cooldown.start()


func _find_target() -> Node:
	var enemies: Array[Node] = EnemySystem.get_active_enemies()
	var in_range: Array[Node] = []

	for enemy: Node in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = position.distance_to(enemy.position)
		if dist <= _range_pixels:
			in_range.append(enemy)

	if in_range.is_empty():
		return null

	match target_mode:
		TargetMode.FIRST:
			return _get_first_enemy(in_range)
		TargetMode.LAST:
			return _get_last_enemy(in_range)
		TargetMode.STRONGEST:
			return _get_strongest_enemy(in_range)
		TargetMode.WEAKEST:
			return _get_weakest_enemy(in_range)
		TargetMode.CLOSEST:
			return _get_closest_enemy(in_range)
	return in_range[0]


func _attack(target: Node) -> void:
	if not is_instance_valid(target):
		return
	_spawn_projectile(target)


func _spawn_projectile(target: Node) -> void:
	var proj: Projectile = _projectile_scene.instantiate() as Projectile
	proj.target = target
	proj.target_last_pos = target.global_position
	proj.tower_data = tower_data
	proj.damage = _calculate_damage(target)
	proj.element = tower_data.element
	proj.global_position = global_position

	# Copy special effect data
	proj.special_key = tower_data.special_key
	proj.special_value = tower_data.special_value
	proj.special_duration = tower_data.special_duration
	proj.special_chance = tower_data.special_chance

	# AoE setup
	if tower_data.special_key == "aoe" and tower_data.aoe_radius_cells > 0.0:
		proj.is_aoe = true
		proj.aoe_radius_px = tower_data.aoe_radius_cells * GridManager.CELL_SIZE

	projectile_spawned.emit(proj)


func _calculate_damage(target: Node) -> int:
	var base_dmg: int = tower_data.damage
	var multiplier: float = _get_element_multiplier(tower_data.element, target.enemy_data.element)
	return int(base_dmg * multiplier)


func _get_element_multiplier(attacker_element: String, target_element: String) -> float:
	# Elemental damage matrix from GDD
	var matrix: Dictionary = {
		"fire":      {"fire": 1.0, "water": 0.5, "earth": 1.5, "wind": 1.0, "lightning": 1.0, "ice": 1.5},
		"water":     {"fire": 1.5, "water": 1.0, "earth": 0.5, "wind": 1.0, "lightning": 0.75, "ice": 1.0},
		"earth":     {"fire": 0.5, "water": 1.5, "earth": 1.0, "wind": 0.75, "lightning": 1.5, "ice": 1.0},
		"wind":      {"fire": 1.0, "water": 1.0, "earth": 1.25, "wind": 1.0, "lightning": 0.5, "ice": 1.5},
		"lightning": {"fire": 1.0, "water": 1.25, "earth": 0.5, "wind": 1.5, "lightning": 1.0, "ice": 1.0},
		"ice":       {"fire": 0.5, "water": 1.0, "earth": 1.0, "wind": 0.5, "lightning": 1.0, "ice": 1.0},
	}
	if attacker_element in matrix and target_element in matrix[attacker_element]:
		return matrix[attacker_element][target_element]
	return 1.0


func _get_first_enemy(enemies: Array[Node]) -> Node:
	var best: Node = null
	var best_progress: float = -1.0
	for enemy: Node in enemies:
		if enemy.path_progress > best_progress:
			best_progress = enemy.path_progress
			best = enemy
	return best


func _get_last_enemy(enemies: Array[Node]) -> Node:
	var best: Node = null
	var best_progress: float = INF
	for enemy: Node in enemies:
		if enemy.path_progress < best_progress:
			best_progress = enemy.path_progress
			best = enemy
	return best


func _get_strongest_enemy(enemies: Array[Node]) -> Node:
	var best: Node = null
	var best_hp: int = -1
	for enemy: Node in enemies:
		if enemy.current_health > best_hp:
			best_hp = enemy.current_health
			best = enemy
	return best


func _get_weakest_enemy(enemies: Array[Node]) -> Node:
	var best: Node = null
	var best_hp: int = 999999
	for enemy: Node in enemies:
		if enemy.current_health < best_hp:
			best_hp = enemy.current_health
			best = enemy
	return best


func _get_closest_enemy(enemies: Array[Node]) -> Node:
	var best: Node = null
	var best_dist: float = INF
	for enemy: Node in enemies:
		var dist: float = position.distance_to(enemy.position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
