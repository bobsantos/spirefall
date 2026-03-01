class_name UpgradeEffect
extends ParticleEffect

## Sparkles rising upward from tower on upgrade. Gold/yellow color.
## 12-16 particles, 0.6s lifetime, upward motion.


func _configure_particles() -> void:
	particles.amount = 14
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.spread = 60.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0.0, -30.0)
	# Upward direction
	particles.direction = Vector2(0.0, -1.0)
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 2.0
	# Gold/yellow sparkle color
	particles.color = Color(1.0, 0.85, 0.2, 1.0)
