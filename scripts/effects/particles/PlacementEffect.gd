class_name PlacementEffect
extends ParticleEffect

## Dust poof when a tower is placed. Earth-toned particles drifting upward.
## 8-10 particles, 0.4s lifetime.


func _configure_particles() -> void:
	particles.amount = 8
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.spread = 90.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.gravity = Vector2.ZERO
	# Upward drift
	particles.direction = Vector2(0.0, -1.0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	# Earth-toned brown/tan
	particles.color = Color(0.65, 0.45, 0.25, 0.8)
