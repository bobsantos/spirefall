class_name Projectile
extends Node2D

## Projectile that travels from tower to target, applying damage and specials on arrival.
## Carries all data needed so the tower can fire-and-forget.

const HIT_THRESHOLD: float = 8.0
const DEFAULT_SPEED: float = 400.0

# Set by the spawning tower before adding to the scene tree
var target: Node = null
var target_last_pos: Vector2 = Vector2.ZERO  # Fallback position if target dies mid-flight
var tower_data: TowerData = null
var damage: int = 0
var element: String = ""
var speed: float = DEFAULT_SPEED

# AoE data (copied from tower_data for convenience)
var is_aoe: bool = false
var aoe_radius_px: float = 0.0

# Special effect data (copied from tower_data)
var special_key: String = ""
var special_value: float = 0.0
var special_duration: float = 0.0
var special_chance: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_load_element_sprite()


func _process(delta: float) -> void:
	# Track the living target's position; keep last known pos as fallback
	if is_instance_valid(target) and target.current_health > 0:
		target_last_pos = target.global_position

	var move_target: Vector2 = target_last_pos
	var direction: Vector2 = (move_target - global_position).normalized()
	global_position += direction * speed * delta

	# Rotate sprite to face travel direction
	rotation = direction.angle()

	if global_position.distance_to(move_target) < HIT_THRESHOLD:
		_hit()


func _hit() -> void:
	if is_aoe:
		_apply_aoe_hit()
	else:
		_apply_single_hit()
	queue_free()


func _apply_single_hit() -> void:
	if not is_instance_valid(target) or target.current_health <= 0:
		return
	target.take_damage(damage, element)
	_try_apply_special(target)


func _apply_aoe_hit() -> void:
	## Deal damage to all enemies within AoE radius of the impact point.
	var impact_pos: Vector2 = global_position
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(impact_pos) <= aoe_radius_px:
			var enemy_dmg: int = _calculate_damage(enemy)
			enemy.take_damage(enemy_dmg, element)

	# Apply special effects to enemies still alive in the AoE
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(impact_pos) <= aoe_radius_px:
			_try_apply_special(enemy)


func _try_apply_special(target_enemy: Node) -> void:
	if special_key == "" or special_key == "aoe":
		return
	if not is_instance_valid(target_enemy) or target_enemy.current_health <= 0:
		return

	# Roll proc chance
	if special_chance < 1.0 and randf() > special_chance:
		return

	match special_key:
		"burn":
			target_enemy.apply_status(StatusEffect.Type.BURN, special_duration, special_value)
		"slow":
			target_enemy.apply_status(StatusEffect.Type.SLOW, special_duration, special_value)
		"freeze":
			target_enemy.apply_status(StatusEffect.Type.FREEZE, special_duration, 1.0)


func _calculate_damage(target_enemy: Node) -> int:
	## Recalculate damage with elemental multiplier for the specific enemy.
	if not tower_data:
		return damage
	var base_dmg: int = tower_data.damage
	var multiplier: float = _get_element_multiplier(element, target_enemy.enemy_data.element)
	return int(base_dmg * multiplier)


func _get_element_multiplier(attacker_element: String, target_element: String) -> float:
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


func _load_element_sprite() -> void:
	if not sprite or element == "":
		return
	var texture_path: String = "res://assets/sprites/projectiles/%s.png" % element
	var tex: Texture2D = load(texture_path)
	if tex:
		sprite.texture = tex
