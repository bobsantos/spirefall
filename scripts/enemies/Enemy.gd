extends Node2D

## Base enemy script. Follows path, takes damage, triggers death/exit.

@export var enemy_data: EnemyData

var max_health: int = 100
var current_health: int = 100
var speed: float = 64.0  # Pixels per second (1 cell/s at 1.0x)
var path_points: PackedVector2Array = PackedVector2Array()
var path_progress: float = 0.0  # 0.0 to 1.0, how far along the path

var _path_index: int = 0
var _base_speed: float = 64.0

# Status effect system
var _status_effects: Array[StatusEffect] = []
var _original_modulate: Color = Color.WHITE

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	if enemy_data:
		_apply_enemy_data()
	if not path_points.is_empty():
		position = path_points[0]


func _apply_enemy_data() -> void:
	max_health = enemy_data.base_health
	current_health = max_health
	speed = _base_speed * enemy_data.speed_multiplier
	_update_health_bar()
	# Load enemy sprite texture from name (e.g. "Boss Ember Titan" -> "boss_ember_titan")
	var texture_name: String = enemy_data.enemy_name.to_lower().replace(" ", "_")
	var texture_path: String = "res://assets/sprites/enemies/%s.png" % texture_name
	sprite.texture = load(texture_path)


func _process(delta: float) -> void:
	_process_status_effects(delta)
	if path_points.is_empty() or _path_index >= path_points.size():
		return
	_move_along_path(delta)


func _move_along_path(delta: float) -> void:
	var target_point: Vector2 = path_points[_path_index]
	var direction: Vector2 = (target_point - position).normalized()
	var move_distance: float = speed * delta
	var distance_to_target: float = position.distance_to(target_point)

	if move_distance >= distance_to_target:
		position = target_point
		_path_index += 1
		if _path_index >= path_points.size():
			_reached_exit()
			return
	else:
		position += direction * move_distance

	# Update progress (0 to 1)
	if path_points.size() > 1:
		path_progress = float(_path_index) / float(path_points.size() - 1)


func take_damage(amount: int, element: String = "") -> void:
	var final_amount: int = _apply_resistance(amount, element)
	# WET enemies take 1.5x damage from lightning
	if element == "lightning" and has_status(StatusEffect.Type.WET):
		final_amount = int(final_amount * 1.5)
	current_health -= final_amount
	_update_health_bar()
	if current_health <= 0:
		_die()


func _apply_resistance(amount: int, element: String) -> int:
	## Reduce damage based on enemy resistances.
	## Physical resist applies to earth-element attacks.
	if enemy_data and enemy_data.physical_resist > 0.0 and element == "earth":
		return int(amount * (1.0 - enemy_data.physical_resist))
	return amount


func _die() -> void:
	EnemySystem.on_enemy_killed(self)


func _reached_exit() -> void:
	EnemySystem.on_enemy_reached_exit(self)


func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = current_health < max_health


# -- Status Effect System --------------------------------------------------

func apply_status(effect_type: StatusEffect.Type, duration: float, value: float) -> void:
	## Apply a status effect to this enemy.
	## Burn stacks are independent (multiple burns tick simultaneously).
	## Slow/Freeze/Stun replace existing slow/freeze/stun (they share the movement slot).
	## WET replaces existing WET (separate slot from movement effects).
	if effect_type == StatusEffect.Type.SLOW or effect_type == StatusEffect.Type.FREEZE or effect_type == StatusEffect.Type.STUN:
		# Replace existing movement-impairing effects rather than stacking
		for i in range(_status_effects.size() - 1, -1, -1):
			var existing: StatusEffect = _status_effects[i]
			if existing.type == StatusEffect.Type.SLOW or existing.type == StatusEffect.Type.FREEZE or existing.type == StatusEffect.Type.STUN:
				_status_effects.remove_at(i)
	elif effect_type == StatusEffect.Type.WET:
		# Replace existing WET
		for i in range(_status_effects.size() - 1, -1, -1):
			if _status_effects[i].type == StatusEffect.Type.WET:
				_status_effects.remove_at(i)
	var effect := StatusEffect.new(effect_type, duration, value)
	_status_effects.append(effect)
	_recalculate_speed()
	_update_status_visuals()


func _process_status_effects(delta: float) -> void:
	if _status_effects.is_empty():
		return

	var burn_damage: float = 0.0
	var any_expired: bool = false

	for effect: StatusEffect in _status_effects:
		burn_damage += effect.tick(delta)
		if effect.is_expired():
			any_expired = true

	# Apply accumulated burn damage (as int, minimum 1 if there was any burn tick)
	if burn_damage > 0.0:
		var dmg: int = max(1, int(burn_damage))
		current_health -= dmg
		_update_health_bar()
		if current_health <= 0:
			_die()
			return

	# Purge expired effects
	if any_expired:
		for i in range(_status_effects.size() - 1, -1, -1):
			if _status_effects[i].is_expired():
				_status_effects.remove_at(i)
		_recalculate_speed()
		_update_status_visuals()


func _recalculate_speed() -> void:
	## Recalculate speed from base, applying the strongest active slow, freeze, or stun.
	var base: float = _base_speed
	if enemy_data:
		base = _base_speed * enemy_data.speed_multiplier

	var has_freeze: bool = false
	var has_stun: bool = false
	var strongest_slow: float = 0.0  # 0-1 fraction

	for effect: StatusEffect in _status_effects:
		if effect.type == StatusEffect.Type.FREEZE:
			has_freeze = true
		elif effect.type == StatusEffect.Type.STUN:
			has_stun = true
		elif effect.type == StatusEffect.Type.SLOW:
			strongest_slow = max(strongest_slow, effect.value)

	if has_freeze or has_stun:
		speed = 0.0
	elif strongest_slow > 0.0:
		speed = base * (1.0 - strongest_slow)
	else:
		speed = base


func _update_status_visuals() -> void:
	## Tint the sprite based on active status effects.
	## Priority: Stun (yellow) > Freeze (cyan) > Slow (blue) > Wet (teal) > Burn (red-orange) > None (white).
	if not sprite:
		return

	var has_stun: bool = false
	var has_freeze: bool = false
	var has_slow: bool = false
	var has_wet: bool = false
	var has_burn: bool = false

	for effect: StatusEffect in _status_effects:
		match effect.type:
			StatusEffect.Type.STUN:
				has_stun = true
			StatusEffect.Type.FREEZE:
				has_freeze = true
			StatusEffect.Type.SLOW:
				has_slow = true
			StatusEffect.Type.WET:
				has_wet = true
			StatusEffect.Type.BURN:
				has_burn = true

	if has_stun:
		sprite.modulate = Color(1.0, 1.0, 0.3, 1.0)  # Yellow tint
	elif has_freeze:
		sprite.modulate = Color(0.5, 0.8, 1.0, 1.0)  # Cyan/ice tint
	elif has_slow:
		sprite.modulate = Color(0.6, 0.6, 1.0, 1.0)  # Blue tint
	elif has_wet:
		sprite.modulate = Color(0.4, 0.7, 0.9, 1.0)  # Teal/blue-green tint
	elif has_burn:
		sprite.modulate = Color(1.0, 0.5, 0.3, 1.0)  # Red-orange tint
	else:
		sprite.modulate = _original_modulate


func has_status(effect_type: StatusEffect.Type) -> bool:
	for effect: StatusEffect in _status_effects:
		if effect.type == effect_type:
			return true
	return false


func clear_all_status_effects() -> void:
	_status_effects.clear()
	_recalculate_speed()
	_update_status_visuals()


func is_wet() -> bool:
	return has_status(StatusEffect.Type.WET)


func push_back(cells: int) -> void:
	## Push the enemy back along its path by the given number of cells.
	## Each cell is approximately one path point step.
	if path_points.is_empty() or _path_index <= 0:
		return
	# Each cell roughly corresponds to one path_index step (64px per cell)
	var steps_back: int = cells
	_path_index = max(0, _path_index - steps_back)
	position = path_points[_path_index]
	# Update progress
	if path_points.size() > 1:
		path_progress = float(_path_index) / float(path_points.size() - 1)


func pull_toward(target_pos: Vector2, max_distance_px: float) -> void:
	## Pull the enemy toward target_pos by up to max_distance_px pixels.
	## Snaps to the closest path point after pulling.
	if path_points.is_empty():
		return
	var direction: Vector2 = (target_pos - position).normalized()
	var pull_dist: float = min(position.distance_to(target_pos), max_distance_px)
	var new_pos: Vector2 = position + direction * pull_dist
	# Find the closest path point to the new position and snap to it
	var best_index: int = _path_index
	var best_dist: float = INF
	for i: int in range(path_points.size()):
		var dist: float = new_pos.distance_to(path_points[i])
		if dist < best_dist:
			best_dist = dist
			best_index = i
	_path_index = best_index
	position = path_points[_path_index]
	if path_points.size() > 1:
		path_progress = float(_path_index) / float(path_points.size() - 1)
