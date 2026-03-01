class_name ParticleEffect
extends Node2D

## Base class for one-shot particle effects that auto-free after emission.
## Subclasses override _configure_particles() to set effect-specific parameters.
## Use spawn(pos, color) to position, tint, and start the effect.

@onready var particles: CPUParticles2D = $Particles

var _cleanup_time: float = 0.0
var _spawned: bool = false


func _ready() -> void:
	_configure_particles()
	particles.one_shot = true
	particles.emitting = false


func spawn(pos: Vector2, color: Color = Color.WHITE) -> void:
	## Position the effect, apply tint color, and begin emission.
	position = pos
	modulate = color
	particles.emitting = true
	_cleanup_time = particles.lifetime + 0.1
	_spawned = true


func _process(delta: float) -> void:
	if not _spawned:
		return
	_cleanup_time -= delta
	if _cleanup_time <= 0.0:
		queue_free()


func _configure_particles() -> void:
	## Override in subclasses to set particle amount, lifetime, spread, etc.
	## Base implementation: minimal burst for testing.
	particles.amount = 8
	particles.lifetime = 0.3
	particles.spread = 45.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 40.0
	particles.gravity = Vector2.ZERO
