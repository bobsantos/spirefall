extends Area2D

## Base tower script. Handles targeting, attacking, and upgrades.

enum TargetMode { FIRST, LAST, STRONGEST, WEAKEST, CLOSEST }

@export var tower_data: TowerData
var grid_position: Vector2i = Vector2i.ZERO
var target_mode: TargetMode = TargetMode.FIRST
var _current_target: Node = null
var _attack_timer: float = 0.0
var _range_pixels: float = 0.0

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
	var dmg: int = _calculate_damage(target)

	match tower_data.special_key:
		"aoe":
			_apply_aoe_damage(target, dmg)
		_:
			target.take_damage(dmg, tower_data.element)

	_apply_special_effect(target)


func _apply_special_effect(target: Node) -> void:
	## Apply the tower's on-hit status effect to the target (if any).
	if tower_data.special_key == "" or tower_data.special_key == "aoe":
		return
	if not is_instance_valid(target) or target.current_health <= 0:
		return

	# Roll proc chance (e.g. freeze is 20%)
	if tower_data.special_chance < 1.0 and randf() > tower_data.special_chance:
		return

	match tower_data.special_key:
		"burn":
			target.apply_status(StatusEffect.Type.BURN, tower_data.special_duration, tower_data.special_value)
		"slow":
			target.apply_status(StatusEffect.Type.SLOW, tower_data.special_duration, tower_data.special_value)
		"freeze":
			target.apply_status(StatusEffect.Type.FREEZE, tower_data.special_duration, 1.0)


func _apply_aoe_damage(center_target: Node, dmg: int) -> void:
	## Deal damage to all enemies within AoE radius of the center target.
	var aoe_radius_px: float = tower_data.aoe_radius_cells * GridManager.CELL_SIZE
	var center_pos: Vector2 = center_target.position
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	for enemy: Node in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.position.distance_to(center_pos) <= aoe_radius_px:
			var enemy_dmg: int = _calculate_damage(enemy)
			enemy.take_damage(enemy_dmg, tower_data.element)


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
