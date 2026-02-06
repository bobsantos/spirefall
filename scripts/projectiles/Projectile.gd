class_name Projectile
extends Node2D

## Projectile that travels from tower to target, applying damage and specials on arrival.
## Carries all data needed so the tower can fire-and-forget.

signal ground_effect_spawned(effect: Node)

const HIT_THRESHOLD: float = 8.0
const DEFAULT_SPEED: float = 400.0
const PULL_DISTANCE_PX: float = 64.0  # 1 cell pull distance toward impact

# Set by the spawning tower before adding to the scene tree
var target: Node = null
var target_last_pos: Vector2 = Vector2.ZERO  # Fallback position if target dies mid-flight
var tower_data: TowerData = null
var damage: int = 0
var element: String = ""
var speed: float = DEFAULT_SPEED
var tower_position: Vector2 = Vector2.ZERO  # Tower's position (for cone direction calc)

# AoE data (copied from tower_data for convenience)
var is_aoe: bool = false
var aoe_radius_px: float = 0.0

# Special effect data (copied from tower_data)
var special_key: String = ""
var special_value: float = 0.0
var special_duration: float = 0.0
var special_chance: float = 1.0

# Chain lightning data (Thunder Pylon and fusion chain variants)
var chain_count: int = 0
var chain_damage_fraction: float = 0.0

# Ground effect scene (lazy-loaded once)
static var _ground_effect_scene: PackedScene = null

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
	# Cone-shaped AoE uses a filtered AoE instead of standard circular
	if special_key == "cone_slow":
		_apply_cone_aoe_hit()
	elif special_key == "pull_burn":
		_apply_pull_burn_hit()
	elif special_key == "pushback":
		_apply_pushback_hit()
	elif is_aoe:
		_apply_aoe_hit()
	else:
		_apply_single_hit()
		if chain_count > 0:
			_apply_chain_hits()

	# Spawn ground effects after dealing damage
	if special_key == "lava_pool" or special_key == "slow_zone":
		_spawn_ground_effect()

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


func _apply_chain_hits() -> void:
	## Chain lightning: deal fractional damage to nearby enemies around the impact point.
	var chain_radius_px: float = 2.0 * GridManager.CELL_SIZE  # 128px (2 cells)
	var impact_pos: Vector2 = global_position
	var enemies: Array[Node] = EnemySystem.get_active_enemies()
	var chain_targets: Array[Node] = []

	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		# Exclude the primary target
		if enemy == target:
			continue
		if enemy.global_position.distance_to(impact_pos) <= chain_radius_px:
			chain_targets.append(enemy)

	# Limit to chain_count secondary targets
	var count: int = mini(chain_count, chain_targets.size())
	for i: int in range(count):
		var chain_enemy: Node = chain_targets[i]
		if not is_instance_valid(chain_enemy) or chain_enemy.current_health <= 0:
			continue
		# Per-target elemental multiplier, then apply chain fraction
		var chain_dmg: int = int(_calculate_damage(chain_enemy) * chain_damage_fraction)
		if chain_dmg < 1:
			chain_dmg = 1
		chain_enemy.take_damage(chain_dmg, element)

	# Apply special effects to chain targets that are still alive
	for i: int in range(count):
		var chain_enemy: Node = chain_targets[i]
		if not is_instance_valid(chain_enemy) or chain_enemy.current_health <= 0:
			continue
		_try_apply_chain_special(chain_enemy)


func _try_apply_chain_special(chain_enemy: Node) -> void:
	## Apply special effects specific to chain-type abilities on chain targets.
	if not is_instance_valid(chain_enemy) or chain_enemy.current_health <= 0:
		return
	match special_key:
		"wet_chain":
			# Storm Beacon: apply WET to all chain targets (always applies)
			chain_enemy.apply_status(StatusEffect.Type.WET, 4.0, 1.0)
		"freeze_chain":
			# Cryo-Volt Array: attempt freeze on chain targets (uses same chance)
			if special_chance < 1.0 and randf() > special_chance:
				return
			chain_enemy.apply_status(StatusEffect.Type.FREEZE, special_duration, 1.0)
		_:
			# Standard chain (Thunder Pylon) -- use normal special logic
			_try_apply_special(chain_enemy)


func _try_apply_special(target_enemy: Node) -> void:
	# Skip keys that are handled structurally (not as status effects on individual targets)
	if special_key == "" or special_key == "aoe" or special_key == "multi" or special_key == "chain":
		return
	# These are handled by dedicated _hit() paths or Tower aura, not per-target specials
	if special_key in ["cone_slow", "pushback", "pull_burn", "lava_pool", "slow_zone", "slow_aura", "wide_slow", "thorn"]:
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
		"stun_pulse":
			# Seismic Coil: stun each enemy (chance already rolled above)
			target_enemy.apply_status(StatusEffect.Type.STUN, special_duration, 1.0)
		"wet_chain":
			# Storm Beacon primary hit: apply WET status
			target_enemy.apply_status(StatusEffect.Type.WET, 4.0, 1.0)
		"freeze_chain":
			# Cryo-Volt Array primary hit: attempt freeze
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


func _apply_cone_aoe_hit() -> void:
	## Blizzard Tower: cone-shaped AoE. Damages and slows enemies in a 90-degree cone
	## from tower toward the target. Uses aoe_radius_px as cone length.
	var impact_pos: Vector2 = global_position
	var cone_direction: Vector2 = (impact_pos - tower_position).normalized()
	var cone_half_angle: float = deg_to_rad(45.0)  # 90-degree cone = 45 each side
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		var to_enemy: Vector2 = enemy.global_position - tower_position
		var dist: float = to_enemy.length()
		if dist > aoe_radius_px:
			continue
		# Check angle: is the enemy within the cone?
		var angle_to_enemy: float = cone_direction.angle_to(to_enemy.normalized())
		if absf(angle_to_enemy) > cone_half_angle:
			continue
		# In cone: deal damage and apply slow
		var enemy_dmg: int = _calculate_damage(enemy)
		enemy.take_damage(enemy_dmg, element)

	# Apply slow to survivors in cone
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		var to_enemy: Vector2 = enemy.global_position - tower_position
		var dist: float = to_enemy.length()
		if dist > aoe_radius_px:
			continue
		var angle_to_enemy: float = cone_direction.angle_to(to_enemy.normalized())
		if absf(angle_to_enemy) > cone_half_angle:
			continue
		enemy.apply_status(StatusEffect.Type.SLOW, special_duration, special_value)


func _apply_pull_burn_hit() -> void:
	## Inferno Vortex: AoE hit that pulls enemies toward impact point, then applies burn.
	var impact_pos: Vector2 = global_position
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	# First pull all enemies in range toward impact
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(impact_pos) <= aoe_radius_px:
			enemy.pull_toward(impact_pos, PULL_DISTANCE_PX)

	# Then deal AoE damage
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(impact_pos) <= aoe_radius_px:
			var enemy_dmg: int = _calculate_damage(enemy)
			enemy.take_damage(enemy_dmg, element)

	# Apply burn to survivors
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(impact_pos) <= aoe_radius_px:
			enemy.apply_status(StatusEffect.Type.BURN, special_duration, special_value)


func _apply_pushback_hit() -> void:
	## Tsunami Shrine: AoE damage + chance to push each enemy back along its path.
	var impact_pos: Vector2 = global_position
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	# Deal AoE damage
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(impact_pos) <= aoe_radius_px:
			var enemy_dmg: int = _calculate_damage(enemy)
			enemy.take_damage(enemy_dmg, element)

	# Roll pushback per enemy
	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(impact_pos) <= aoe_radius_px:
			if special_chance >= 1.0 or randf() <= special_chance:
				enemy.push_back(int(special_value))


func _spawn_ground_effect() -> void:
	## Spawn a persistent ground effect (lava pool or slow zone) at the impact point.
	if _ground_effect_scene == null:
		_ground_effect_scene = load("res://scenes/effects/GroundEffect.tscn")
	if _ground_effect_scene == null:
		push_error("Projectile: Could not load GroundEffect.tscn")
		return

	var effect: Node = _ground_effect_scene.instantiate()
	effect.global_position = global_position
	effect.effect_radius_px = aoe_radius_px
	effect.effect_duration = special_duration
	effect.element = element

	if special_key == "lava_pool":
		effect.effect_type = "lava_pool"
		effect.damage_per_second = special_value
	elif special_key == "slow_zone":
		effect.effect_type = "slow_zone"
		effect.slow_fraction = special_value

	ground_effect_spawned.emit(effect)


func _load_element_sprite() -> void:
	if not sprite or element == "":
		return
	var texture_path: String = "res://assets/sprites/projectiles/%s.png" % element
	var tex: Texture2D = load(texture_path)
	if tex:
		sprite.texture = tex
