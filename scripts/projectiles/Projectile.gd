extends Node2D

## Simple projectile that moves toward a target and deals damage on hit.

var target: Node = null
var damage: int = 0
var element: String = ""
var speed: float = 300.0

@onready var sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var direction: Vector2 = (target.position - position).normalized()
	position += direction * speed * delta

	if position.distance_to(target.position) < 8.0:
		_hit()


func _hit() -> void:
	if is_instance_valid(target):
		target.take_damage(damage, element)
	queue_free()
