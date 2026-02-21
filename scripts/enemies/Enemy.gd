extends Node2D

## Base enemy script. Follows path, takes damage, triggers death/exit.
## Supports behaviors: healer aura, split on death, stealth, elemental immunity/weakness.
## Boss enemies can have timed abilities (fire trail, tower freeze, element cycling).

signal ground_effect_spawned(effect: Node)

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

# Stealth system
var _is_revealed: bool = false

# Healer visual feedback
var _heal_flash_timer: float = 0.0
const HEAL_FLASH_DURATION: float = 0.15

# Flying bobbing effect
var _is_flying: bool = false
var _bob_time: float = 0.0
const BOB_AMPLITUDE: float = 6.0   # Pixels up/down
const BOB_FREQUENCY: float = 2.5   # Cycles per second

# Boss ability system
var _boss_ability_timer: float = 0.0
var _minion_spawn_timer: float = 0.0

# Chaos Elemental cycling state
var _chaos_element_index: int = 0
var _chaos_cycle_count: int = 0

# Ground effect scene (lazy-loaded for boss fire trail)
static var _ground_effect_scene: PackedScene = null


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

	# Boss: render above other entities and scale up for visibility
	if enemy_data.is_boss:
		z_index = 5
		if sprite:
			sprite.scale = Vector2(2.5, 2.5)
		# Shift health bar up to clear the larger sprite
		if health_bar:
			health_bar.position.y = -60.0

	# Flying: render above ground enemies and enable bobbing
	if enemy_data.is_flying:
		_is_flying = true
		z_index = 1

	# Stealth: start nearly invisible
	if enemy_data.stealth:
		_is_revealed = false
		sprite.modulate = Color(1, 1, 1, 0.15)
		_original_modulate = Color(1, 1, 1, 0.15)

	# Elemental: assign random immune/weak elements per instance
	if enemy_data.enemy_name == "Elemental" and enemy_data.immune_element == "":
		_assign_elemental_affinity()


func _assign_elemental_affinity() -> void:
	## Assign random immune and weak elements for Elemental enemy type.
	## Seeded by wave number for deterministic results within a wave,
	## but each instance gets a unique offset from its instance ID.
	var elements: Array[String] = ElementMatrix.get_elements()
	var seed_value: int = GameManager.current_wave * 1000 + get_instance_id()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var immune_idx: int = rng.randi_range(0, elements.size() - 1)
	enemy_data.immune_element = elements[immune_idx]
	# Weak element is the counter from the element matrix
	var counter: String = ElementMatrix.get_counter(enemy_data.immune_element)
	if counter != "":
		enemy_data.weak_element = counter
	else:
		# Fallback: pick a different random element
		var weak_idx: int = (immune_idx + 1) % elements.size()
		enemy_data.weak_element = elements[weak_idx]
	# Tint sprite to immune element color
	var tint: Color = ElementMatrix.get_color(enemy_data.immune_element)
	if tint != Color.WHITE:
		sprite.modulate = tint
		_original_modulate = tint


func _process(delta: float) -> void:
	_process_status_effects(delta)
	if path_points.is_empty() or _path_index >= path_points.size():
		return

	# Healer aura: heal nearby allies each frame
	if enemy_data and enemy_data.heal_per_second > 0.0:
		_heal_nearby(delta)

	# Heal flash fade
	if _heal_flash_timer > 0.0:
		_heal_flash_timer -= delta
		if _heal_flash_timer <= 0.0:
			# Restore to whatever the current status visual should be
			_update_status_visuals()

	# Stealth reveal check
	if enemy_data and enemy_data.stealth and not _is_revealed:
		_check_stealth_reveal()

	# Boss ability system
	if enemy_data and enemy_data.is_boss and enemy_data.boss_ability_key != "":
		_tick_boss_ability(delta)

	_move_along_path(delta)

	# Flying bob: offset sprite and health bar vertically with a sine wave.
	# Applied to child nodes, not to position, so targeting/collision stay accurate.
	if _is_flying:
		_bob_time += delta
		var bob_offset: float = sin(_bob_time * BOB_FREQUENCY * TAU) * BOB_AMPLITUDE
		sprite.position.y = bob_offset
		health_bar.position.y = bob_offset


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
	# Stunned enemies take 2x damage from all sources (Crystalline Monolith synergy)
	if has_status(StatusEffect.Type.STUN):
		final_amount = int(final_amount * 2.0)
	current_health -= final_amount
	_update_health_bar()
	if current_health <= 0:
		_die()


func _apply_resistance(amount: int, element: String) -> int:
	## Reduce damage based on enemy resistances.
	## Elemental immunity: damage from immune element is reduced to 0.
	## Elemental weakness: damage from weak element is doubled.
	## Physical resist applies to earth-element attacks.
	if enemy_data:
		# Elemental immunity check (takes priority)
		if enemy_data.immune_element != "" and element == enemy_data.immune_element:
			return 0
		# Elemental weakness check
		if enemy_data.weak_element != "" and element == enemy_data.weak_element:
			return int(amount * 2.0)
		# Physical resist for earth attacks
		if enemy_data.physical_resist > 0.0 and element == "earth":
			return int(amount * (1.0 - enemy_data.physical_resist))
	return amount


func _die() -> void:
	# Split enemies spawn children instead of just dying.
	# Must spawn children BEFORE removing parent from active list to prevent
	# premature wave_cleared (children must be in _active_enemies first).
	if enemy_data and enemy_data.split_on_death and enemy_data.split_data != null:
		EnemySystem.spawn_split_enemies(self)
		return
	EnemySystem.on_enemy_killed(self)


func _reached_exit() -> void:
	EnemySystem.on_enemy_reached_exit(self)


func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = current_health < max_health


# -- Healer Behavior --------------------------------------------------------

func _heal_nearby(delta: float) -> void:
	## Heal all ally enemies within 2-cell radius (128px). Does NOT heal self.
	var heal_radius_px: float = 2.0 * GridManager.CELL_SIZE  # 128px
	var heal_amount: float = enemy_data.heal_per_second * delta
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	for ally: Node in enemies:
		if ally == self:
			continue
		if not is_instance_valid(ally) or ally.current_health <= 0:
			continue
		if position.distance_to(ally.position) > heal_radius_px:
			continue
		# Only heal if ally is actually damaged
		if ally.current_health >= ally.max_health:
			continue
		ally.current_health = mini(ally.current_health + int(ceil(heal_amount)), ally.max_health)
		ally._update_health_bar()
		# Brief green flash on healed ally (don't override if already flashing)
		if ally._heal_flash_timer <= 0.0 and ally.sprite:
			ally.sprite.modulate = Color(0.5, 1.0, 0.5)
			ally._heal_flash_timer = HEAL_FLASH_DURATION


func heal(amount: int) -> void:
	## Public method to heal this enemy by a flat amount (capped at max_health).
	current_health = mini(current_health + amount, max_health)
	_update_health_bar()


# -- Stealth Behavior -------------------------------------------------------

func _check_stealth_reveal() -> void:
	## Check if any tower is within 2 cells (128px) of this enemy. If so, reveal permanently.
	var reveal_radius_px: float = 2.0 * GridManager.CELL_SIZE  # 128px
	var towers: Array[Node] = TowerSystem.get_active_towers()

	for tower: Node in towers:
		if not is_instance_valid(tower):
			continue
		if position.distance_to(tower.position) <= reveal_radius_px:
			_is_revealed = true
			sprite.modulate.a = 1.0
			_original_modulate = Color.WHITE
			_update_status_visuals()
			return


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
	## Also accounts for Chaos Elemental soft enrage multiplier.
	var base: float = _base_speed
	if enemy_data:
		base = _base_speed * enemy_data.speed_multiplier
	# Chaos Elemental soft enrage: 10% speed per cycle
	if _chaos_cycle_count > 0:
		base *= (1.0 + 0.1 * _chaos_cycle_count)

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
	## Priority: Stun (yellow) > Freeze (cyan) > Slow (blue) > Wet (teal) > Burn (red-orange) > None (original).
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
		sprite.modulate = Color(1.0, 1.0, 0.3, _original_modulate.a)  # Yellow tint
	elif has_freeze:
		sprite.modulate = Color(0.5, 0.8, 1.0, _original_modulate.a)  # Cyan/ice tint
	elif has_slow:
		sprite.modulate = Color(0.6, 0.6, 1.0, _original_modulate.a)  # Blue tint
	elif has_wet:
		sprite.modulate = Color(0.4, 0.7, 0.9, _original_modulate.a)  # Teal/blue-green tint
	elif has_burn:
		sprite.modulate = Color(1.0, 0.5, 0.3, _original_modulate.a)  # Red-orange tint
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


# -- Boss Ability System ----------------------------------------------------

func _tick_boss_ability(delta: float) -> void:
	## Runs boss ability timers and triggers abilities when ready.
	_boss_ability_timer += delta
	if _boss_ability_timer >= enemy_data.boss_ability_interval:
		_boss_ability_timer -= enemy_data.boss_ability_interval
		match enemy_data.boss_ability_key:
			"fire_trail":
				_boss_fire_trail()
			"tower_freeze":
				_boss_tower_freeze()
			"element_cycle":
				_boss_element_cycle()

	# Minion spawning on a separate timer (Glacial Wyrm)
	if enemy_data.minion_data != null and enemy_data.minion_spawn_interval > 0.0:
		_minion_spawn_timer += delta
		if _minion_spawn_timer >= enemy_data.minion_spawn_interval:
			_minion_spawn_timer -= enemy_data.minion_spawn_interval
			EnemySystem.spawn_boss_minions(self, enemy_data.minion_data, enemy_data.minion_spawn_count)


func _boss_fire_trail() -> void:
	## Ember Titan: spawn a fire trail ground effect at the boss's current position.
	## The trail deals burn damage to enemies and disables nearby towers (handled by GroundEffect).
	if _ground_effect_scene == null:
		_ground_effect_scene = load("res://scenes/effects/GroundEffect.tscn")
	if _ground_effect_scene == null:
		push_error("Enemy: Could not load GroundEffect.tscn for boss fire trail")
		return

	var effect: Node = _ground_effect_scene.instantiate()
	effect.global_position = global_position
	effect.effect_type = "fire_trail"
	effect.effect_radius_px = GridManager.CELL_SIZE * 1.0  # 1 cell radius (64px)
	effect.effect_duration = 3.0
	effect.damage_per_second = 15.0  # Moderate burn damage
	effect.element = "fire"

	ground_effect_spawned.emit(effect)


func _boss_tower_freeze() -> void:
	## Glacial Wyrm: freeze all towers within 3-cell radius for 3 seconds.
	var freeze_radius_px: float = 3.0 * GridManager.CELL_SIZE  # 192px
	var towers: Array[Node] = TowerSystem.get_active_towers()

	for tower: Node in towers:
		if not is_instance_valid(tower):
			continue
		if tower.global_position.distance_to(global_position) <= freeze_radius_px:
			tower.disable_for(3.0)


func _boss_element_cycle() -> void:
	## Chaos Elemental: cycle to the next element. Becomes immune to the new element
	## and weak to its counter. Gains 10% speed per cycle (soft enrage).
	_chaos_element_index = (_chaos_element_index + 1) % ElementMatrix.ELEMENTS.size()
	_chaos_cycle_count += 1

	var new_element: String = ElementMatrix.ELEMENTS[_chaos_element_index]
	enemy_data.immune_element = new_element
	enemy_data.weak_element = ElementMatrix.get_counter(new_element)

	# Soft enrage: 10% speed per cycle (handled by _recalculate_speed)
	_recalculate_speed()

	# Visual: tint sprite to match current immune element
	if sprite:
		var tint: Color = ElementMatrix.get_color(new_element)
		sprite.modulate = tint
		_original_modulate = tint
