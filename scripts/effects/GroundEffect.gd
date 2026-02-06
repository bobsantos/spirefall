class_name GroundEffect
extends Node2D

## Persistent ground effect that damages or slows enemies within a radius.
## Spawned by projectiles on impact (lava_pool, slow_zone, burning_ground).
## Auto-frees when duration expires.

var effect_type: String = ""  # "lava_pool", "slow_zone", or "burning_ground"
var effect_radius_px: float = 96.0
var effect_duration: float = 3.0
var element: String = ""

# lava_pool / burning_ground specific
var damage_per_second: float = 0.0

# slow_zone specific
var slow_fraction: float = 0.0

var _tick_interval: float = 0.5
var _tick_timer: float = 0.0
var _lifetime: float = 0.0


func _ready() -> void:
	# Visual indicator: semi-transparent colored circle
	_update_visual()


func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= effect_duration:
		queue_free()
		return

	_tick_timer += delta
	if _tick_timer >= _tick_interval:
		_tick_timer -= _tick_interval
		_apply_effect()

	# Fade out in the last 0.5 seconds
	var remaining: float = effect_duration - _lifetime
	if remaining < 0.5:
		modulate.a = remaining / 0.5


func _apply_effect() -> void:
	var enemies: Array[Node] = EnemySystem.get_active_enemies()

	for enemy: Node in enemies:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.global_position.distance_to(global_position) > effect_radius_px:
			continue

		match effect_type:
			"lava_pool", "burning_ground":
				# Deal burn damage per tick (scaled by tick interval)
				var tick_damage: int = max(1, int(damage_per_second * _tick_interval))
				enemy.take_damage(tick_damage, element)
			"slow_zone":
				# Re-apply slow each tick to keep enemies slowed while inside
				enemy.apply_status(StatusEffect.Type.SLOW, _tick_interval + 0.1, slow_fraction)


func _update_visual() -> void:
	# Draw a colored circle as a simple visual for the ground effect
	queue_redraw()


func _draw() -> void:
	var color: Color
	match effect_type:
		"lava_pool":
			color = Color(1.0, 0.3, 0.1, 0.3)  # Semi-transparent orange-red
		"burning_ground":
			color = Color(1.0, 0.5, 0.0, 0.3)  # Semi-transparent orange (distinct from lava)
		"slow_zone":
			color = Color(0.4, 0.3, 0.2, 0.3)  # Semi-transparent brown
		_:
			color = Color(1.0, 1.0, 1.0, 0.2)
	draw_circle(Vector2.ZERO, effect_radius_px, color)
