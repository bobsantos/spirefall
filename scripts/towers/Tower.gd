extends Area2D

## Base tower script. Handles targeting, attacking via projectiles, upgrades,
## aura effects, thorn damage, freeze_burn alternation, and legendary periodic abilities.

signal projectile_spawned(projectile: Node)

enum TargetMode { FIRST, LAST, STRONGEST, WEAKEST, CLOSEST }

# Aura special keys that apply passive effects each tick instead of (only) via projectiles
const AURA_KEYS: PackedStringArray = ["slow_aura", "wide_slow", "thorn", "blizzard_aura"]

# Legendary tower special keys that trigger a periodic AoE ability on a separate timer
const PERIODIC_KEYS: PackedStringArray = ["geyser", "stun_amplify"]

@export var tower_data: TowerData
var grid_position: Vector2i = Vector2i.ZERO
var target_mode: TargetMode = TargetMode.FIRST
var _current_target: Node = null
var _attack_timer: float = 0.0
var _range_pixels: float = 0.0

# Aura system: ticks every _aura_interval seconds
var _aura_timer: float = 0.0
var _aura_interval: float = 0.5

# Periodic ability system (geyser, stun_amplify): fires on a separate interval
var _ability_timer: float = 0.0
var _ability_interval: float = 0.0

# freeze_burn alternation: toggles each attack between freeze and burn
var _attack_parity: bool = false  # false = freeze, true = burn

# Disable mechanic: bosses can temporarily disable towers (no attacking, visual feedback)
var _is_disabled: bool = false
var _disable_timer: float = 0.0

# Element synergy cached bonuses (refreshed on synergy_changed signal)
var _synergy_damage_mult: float = 1.0
var _synergy_attack_speed_bonus: float = 0.0
var _synergy_range_bonus_cells: int = 0
var _synergy_chain_bonus: int = 0
var _synergy_freeze_chance_bonus: float = 0.0
var _synergy_slow_bonus: float = 0.0
var _synergy_color: Color = Color.WHITE

var _projectile_scene: PackedScene = preload("res://scenes/projectiles/BaseProjectile.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var attack_cooldown: Timer = $AttackCooldown


func _ready() -> void:
	if tower_data:
		apply_tower_data()
	ElementSynergy.synergy_changed.connect(_on_synergy_changed)


func apply_tower_data() -> void:
	# Refresh synergy bonuses before applying stats
	_refresh_synergy_bonuses()

	# Range includes earth synergy bonus
	var effective_range_cells: float = tower_data.range_cells + _synergy_range_bonus_cells
	_range_pixels = effective_range_cells * GridManager.CELL_SIZE
	# Update collision shape to match range
	var shape := CircleShape2D.new()
	shape.radius = _range_pixels
	collision.shape = shape
	# Set attack cooldown with fire/wind synergy speed bonus
	if tower_data.attack_speed > 0.0:
		var effective_speed: float = tower_data.attack_speed * (1.0 + _synergy_attack_speed_bonus)
		attack_cooldown.wait_time = 1.0 / effective_speed
		attack_cooldown.one_shot = true
	# Configure periodic ability interval for legendary towers
	_ability_timer = 0.0
	if tower_data.special_key == "geyser":
		_ability_interval = tower_data.special_duration  # 10s interval
	elif tower_data.special_key == "stun_amplify":
		_ability_interval = 8.0  # Fixed 8s interval for stun amplify pulse
	else:
		_ability_interval = 0.0
	# Load tower sprite texture from name (e.g. "Flame Spire" -> "flame_spire")
	var texture_name: String = tower_data.tower_name.to_lower().replace(" ", "_")
	var texture_path: String = "res://assets/sprites/towers/%s.png" % texture_name
	var tex: Texture2D = load(texture_path)
	if tex == null:
		# Fallback: strip "_enhanced" or "_superior" suffix to find base sprite
		texture_name = texture_name.replace("_enhanced", "").replace("_superior", "")
		texture_path = "res://assets/sprites/towers/%s.png" % texture_name
		tex = load(texture_path)
	if tex:
		sprite.texture = tex
	# Apply synergy visual tint (only when not disabled)
	if not _is_disabled and sprite:
		sprite.modulate = _synergy_color


func _process(delta: float) -> void:
	if GameManager.game_state != GameManager.GameState.COMBAT_PHASE:
		return

	# Disable mechanic: count down timer and skip all tower behavior while disabled
	if _is_disabled:
		_disable_timer -= delta
		if _disable_timer <= 0.0:
			_is_disabled = false
			_disable_timer = 0.0
			# Restore synergy tint (or WHITE if no synergy active)
			if sprite:
				sprite.modulate = _synergy_color
		return

	# Aura passive effects tick independently of attacks
	if tower_data and tower_data.special_key in AURA_KEYS:
		_tick_aura(delta)

	# Periodic legendary abilities tick independently of attacks
	if tower_data and tower_data.special_key in PERIODIC_KEYS:
		_tick_periodic_ability(delta)

	# Skip normal projectile attack for pure-aura towers (attack_speed == 0.0)
	if tower_data and tower_data.attack_speed <= 0.0:
		return

	# Normal projectile attack
	_current_target = _find_target()
	if _current_target and attack_cooldown.is_stopped():
		_attack(_current_target)
		attack_cooldown.start()


func _get_in_range_enemies() -> Array[Node]:
	## Returns all valid enemies within this tower's range.
	## Stealth enemies that have not been revealed are excluded (untargetable).
	var enemies: Array[Node] = EnemySystem.get_active_enemies()
	var in_range: Array[Node] = []
	for enemy: Node in enemies:
		if not is_instance_valid(enemy):
			continue
		# Stealth enemies are untargetable until revealed
		if enemy.enemy_data and enemy.enemy_data.stealth and not enemy._is_revealed:
			continue
		var dist: float = position.distance_to(enemy.position)
		if dist <= _range_pixels:
			in_range.append(enemy)
	return in_range


func _sort_by_target_mode(enemies: Array[Node]) -> Array[Node]:
	## Returns enemies sorted by current targeting priority (best first).
	var sorted: Array[Node] = enemies.duplicate()
	match target_mode:
		TargetMode.FIRST:
			sorted.sort_custom(func(a: Node, b: Node) -> bool: return a.path_progress > b.path_progress)
		TargetMode.LAST:
			sorted.sort_custom(func(a: Node, b: Node) -> bool: return a.path_progress < b.path_progress)
		TargetMode.STRONGEST:
			sorted.sort_custom(func(a: Node, b: Node) -> bool: return a.current_health > b.current_health)
		TargetMode.WEAKEST:
			sorted.sort_custom(func(a: Node, b: Node) -> bool: return a.current_health < b.current_health)
		TargetMode.CLOSEST:
			sorted.sort_custom(func(a: Node, b: Node) -> bool:
				return position.distance_to(a.position) < position.distance_to(b.position))
	return sorted


func _find_target() -> Node:
	var in_range: Array[Node] = _get_in_range_enemies()
	if in_range.is_empty():
		return null
	var sorted: Array[Node] = _sort_by_target_mode(in_range)
	return sorted[0]


func _find_multiple_targets(count: int) -> Array[Node]:
	## Returns up to `count` enemies in range, sorted by targeting priority.
	var in_range: Array[Node] = _get_in_range_enemies()
	if in_range.is_empty():
		return []
	var sorted: Array[Node] = _sort_by_target_mode(in_range)
	return sorted.slice(0, count)


func _attack(target: Node) -> void:
	if not is_instance_valid(target):
		return
	# Multi-target: spawn one projectile per target (e.g. Gale Tower)
	if tower_data.special_key == "multi" and tower_data.special_value > 1.0:
		var targets: Array[Node] = _find_multiple_targets(int(tower_data.special_value))
		for t: Node in targets:
			_spawn_projectile(t)
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
	proj.tower_position = global_position  # Used by cone_slow and pull_burn

	# Copy special effect data
	proj.special_key = tower_data.special_key
	proj.special_value = tower_data.special_value
	proj.special_duration = tower_data.special_duration
	proj.special_chance = tower_data.special_chance

	# freeze_burn alternation: override special_key to alternate freeze/burn each attack
	if tower_data.special_key == "freeze_burn":
		if _attack_parity:
			proj.special_key = "burn"
			# Use special_value as burn dmg/s, special_duration as duration
		else:
			proj.special_key = "freeze"
			# Freeze uses value=1.0 (convention), duration from tower_data
		_attack_parity = not _attack_parity

	# Aura towers fire normal projectiles with a secondary effect:
	# Glacier Keep ("slow_aura"): projectiles attempt freeze (chance from special_chance)
	# Sandstorm Citadel ("wide_slow") and Permafrost Pillar ("thorn"): plain damage projectiles
	if tower_data.special_key == "slow_aura":
		proj.special_key = "freeze"
		# special_chance is already copied (0.3 for Glacier Keep)
	elif tower_data.special_key == "wide_slow" or tower_data.special_key == "thorn":
		proj.special_key = ""

	# Periodic ability towers (geyser, stun_amplify) fire normal projectiles;
	# their periodic effect is handled by _tick_periodic_ability(), not projectiles
	if tower_data.special_key in PERIODIC_KEYS:
		proj.special_key = ""

	# AoE setup: trigger whenever aoe_radius_cells > 0 regardless of special_key.
	# Exception: aura towers use aoe_radius_cells for the aura range, not projectile AoE.
	# Exception: periodic ability towers use aoe_radius_cells for the ability range, not projectile AoE.
	if tower_data.aoe_radius_cells > 0.0 and tower_data.special_key not in AURA_KEYS and tower_data.special_key not in PERIODIC_KEYS:
		proj.is_aoe = true
		proj.aoe_radius_px = tower_data.aoe_radius_cells * GridManager.CELL_SIZE

	# Chain lightning setup (standard "chain" and fusion chain variants)
	if tower_data.special_key == "chain" or tower_data.special_key == "freeze_chain" or tower_data.special_key == "wet_chain":
		proj.chain_count = int(tower_data.special_value) + _synergy_chain_bonus
		proj.chain_damage_fraction = tower_data.chain_damage_fraction

	# Pass synergy bonuses to projectile for damage and special calculations
	proj.synergy_damage_mult = _synergy_damage_mult
	proj.synergy_freeze_chance_bonus = _synergy_freeze_chance_bonus
	proj.synergy_slow_bonus = _synergy_slow_bonus

	projectile_spawned.emit(proj)


func _calculate_damage(target: Node) -> int:
	var base_dmg: int = tower_data.damage
	var multiplier: float = _get_element_multiplier(tower_data.element, target.enemy_data.element)
	# Apply element synergy damage bonus
	multiplier *= _synergy_damage_mult
	var final_dmg: int = int(base_dmg * multiplier)
	# Storm AoE wave scaling: damage increases by special_value% per wave
	if tower_data.special_key == "storm_aoe":
		final_dmg = int(final_dmg * (1.0 + tower_data.special_value * GameManager.current_wave))
	return final_dmg


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


func _tick_aura(delta: float) -> void:
	## Passive aura effects applied every _aura_interval seconds to enemies in range.
	_aura_timer += delta
	if _aura_timer < _aura_interval:
		return
	_aura_timer -= _aura_interval

	var aura_range_px: float = tower_data.aoe_radius_cells * GridManager.CELL_SIZE
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	# Apply synergy bonuses to aura effects
	var slow_value: float = tower_data.special_value + _synergy_slow_bonus
	var freeze_chance: float = tower_data.special_chance + _synergy_freeze_chance_bonus

	match tower_data.special_key:
		"slow_aura":
			# Glacier Keep: apply slow to all enemies in aura range
			for enemy: Node in enemies:
				if not is_instance_valid(enemy) or enemy.current_health <= 0:
					continue
				if position.distance_to(enemy.position) <= aura_range_px:
					enemy.apply_status(StatusEffect.Type.SLOW, tower_data.special_duration, slow_value)
		"wide_slow":
			# Sandstorm Citadel: continuously slow all enemies in range
			for enemy: Node in enemies:
				if not is_instance_valid(enemy) or enemy.current_health <= 0:
					continue
				if position.distance_to(enemy.position) <= aura_range_px:
					enemy.apply_status(StatusEffect.Type.SLOW, tower_data.special_duration, slow_value)
		"thorn":
			# Permafrost Pillar: deal damage per second to all enemies in range
			# Damage per tick = special_value * _aura_interval (since value is dmg/s)
			var thorn_range_px: float = tower_data.range_cells * GridManager.CELL_SIZE
			var tick_damage: int = max(1, int(tower_data.special_value * _aura_interval))
			for enemy: Node in enemies:
				if not is_instance_valid(enemy) or enemy.current_health <= 0:
					continue
				if position.distance_to(enemy.position) <= thorn_range_px:
					enemy.take_damage(tick_damage, tower_data.element)
		"blizzard_aura":
			# Arctic Maelstrom: permanent blizzard -- 50% slow + 15% freeze chance per tick
			for enemy: Node in enemies:
				if not is_instance_valid(enemy) or enemy.current_health <= 0:
					continue
				if position.distance_to(enemy.position) <= aura_range_px:
					# Always apply slow (with water synergy bonus if applicable)
					enemy.apply_status(StatusEffect.Type.SLOW, tower_data.special_duration, slow_value)
					# Roll freeze chance each tick (with ice synergy bonus)
					if randf() <= freeze_chance:
						enemy.apply_status(StatusEffect.Type.FREEZE, tower_data.special_duration, 1.0)


func _tick_periodic_ability(delta: float) -> void:
	## Legendary periodic abilities fire on a separate timer, dealing effects directly
	## to enemies in range (not via projectiles). Tower still fires normal projectiles.
	if _ability_interval <= 0.0:
		return
	_ability_timer += delta
	if _ability_timer < _ability_interval:
		return
	_ability_timer -= _ability_interval

	var ability_range_px: float = tower_data.aoe_radius_cells * GridManager.CELL_SIZE
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	match tower_data.special_key:
		"geyser":
			# Primordial Nexus: massive AoE burst dealing special_value damage + slow
			for enemy: Node in enemies:
				if not is_instance_valid(enemy) or enemy.current_health <= 0:
					continue
				if position.distance_to(enemy.position) <= ability_range_px:
					enemy.take_damage(int(tower_data.special_value), tower_data.element)
			# Apply slow to survivors (3s slow at 40%)
			for enemy: Node in enemies:
				if not is_instance_valid(enemy) or enemy.current_health <= 0:
					continue
				if position.distance_to(enemy.position) <= ability_range_px:
					enemy.apply_status(StatusEffect.Type.SLOW, 3.0, 0.4)
		"stun_amplify":
			# Crystalline Monolith: stun all enemies in range for special_duration seconds
			for enemy: Node in enemies:
				if not is_instance_valid(enemy) or enemy.current_health <= 0:
					continue
				if position.distance_to(enemy.position) <= ability_range_px:
					enemy.apply_status(StatusEffect.Type.STUN, tower_data.special_duration, 1.0)


func disable_for(duration: float) -> void:
	## Temporarily disable this tower for the given duration (seconds).
	## While disabled, the tower cannot attack, run auras, or use abilities.
	## If already disabled, extends to whichever duration is longer.
	_is_disabled = true
	_disable_timer = maxf(_disable_timer, duration)
	# Visual feedback: blue-ish frozen tint
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.8, 0.7)


func is_disabled() -> bool:
	return _is_disabled


func _refresh_synergy_bonuses() -> void:
	## Query ElementSynergy for current bonuses and cache them.
	_synergy_damage_mult = ElementSynergy.get_best_synergy_bonus(self)
	_synergy_attack_speed_bonus = ElementSynergy.get_attack_speed_bonus(self)
	_synergy_range_bonus_cells = ElementSynergy.get_range_bonus_cells(self)
	_synergy_chain_bonus = ElementSynergy.get_chain_bonus(self)
	_synergy_freeze_chance_bonus = ElementSynergy.get_freeze_chance_bonus(self)
	_synergy_slow_bonus = ElementSynergy.get_slow_bonus(self)
	_synergy_color = ElementSynergy.get_synergy_color(self)


func _on_synergy_changed() -> void:
	## Called when any element synergy tier changes. Reapply tower stats.
	if not tower_data:
		return
	apply_tower_data()
