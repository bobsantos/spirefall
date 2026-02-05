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


func take_damage(amount: int, _element: String = "") -> void:
	current_health -= amount
	_update_health_bar()
	if current_health <= 0:
		_die()


func _die() -> void:
	EnemySystem.on_enemy_killed(self)


func _reached_exit() -> void:
	EnemySystem.on_enemy_reached_exit(self)


func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = current_health < max_health
