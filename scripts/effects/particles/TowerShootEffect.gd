class_name TowerShootEffect
extends ParticleEffect

## Small burst at tower position when firing. Element-colored via spawn().
## 8-12 particles, 0.3s lifetime, small directional spread.


func _configure_particles() -> void:
	particles.amount = 10
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.spread = 30.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.direction = Vector2(1.0, 0.0)
