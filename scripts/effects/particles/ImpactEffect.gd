class_name ImpactEffect
extends ParticleEffect

## Burst at projectile hit position. Element-colored via spawn().
## 10-15 particles, 0.4s lifetime, full radial spread.


func _configure_particles() -> void:
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.direction = Vector2(1.0, 0.0)
