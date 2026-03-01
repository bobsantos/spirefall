class_name EnemyDeathEffect
extends ParticleEffect

## Pop/explosion when an enemy dies. White/neutral by default.
## 15-20 particles, 0.5s lifetime, radial burst.


func _configure_particles() -> void:
	particles.amount = 18
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2(0.0, 50.0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.direction = Vector2(1.0, 0.0)
	# White/neutral color by default
	particles.color = Color.WHITE
