extends GdUnitTestSuite

## Unit tests for ParticleEffect base class and all particle effect types.
## Covers: auto-free after emission, spawn() API, element coloring,
## particle configuration (amount, lifetime, spread), and individual
## effect type behaviors (TowerShoot, Impact, EnemyDeath, Placement, Upgrade).

# -- Static script references --------------------------------------------------

static var _particle_effect_script: GDScript = null
static var _tower_shoot_script: GDScript = null
static var _impact_script: GDScript = null
static var _enemy_death_script: GDScript = null
static var _placement_script: GDScript = null
static var _upgrade_script: GDScript = null


func _load_scripts() -> void:
	if _particle_effect_script == null:
		_particle_effect_script = load("res://scripts/effects/ParticleEffect.gd") as GDScript
	if _tower_shoot_script == null:
		_tower_shoot_script = load("res://scripts/effects/particles/TowerShootEffect.gd") as GDScript
	if _impact_script == null:
		_impact_script = load("res://scripts/effects/particles/ImpactEffect.gd") as GDScript
	if _enemy_death_script == null:
		_enemy_death_script = load("res://scripts/effects/particles/EnemyDeathEffect.gd") as GDScript
	if _placement_script == null:
		_placement_script = load("res://scripts/effects/particles/PlacementEffect.gd") as GDScript
	if _upgrade_script == null:
		_upgrade_script = load("res://scripts/effects/particles/UpgradeEffect.gd") as GDScript


# -- Helpers -------------------------------------------------------------------

func _create_effect(script: GDScript) -> Node2D:
	var node := Node2D.new()
	var cpu_particles := CPUParticles2D.new()
	cpu_particles.name = "Particles"
	node.add_child(cpu_particles)
	node.set_script(script)
	# @onready vars don't resolve outside the scene tree; assign manually
	node.particles = cpu_particles
	# Simulate _ready() behavior: configure particles
	node._configure_particles()
	cpu_particles.one_shot = true
	cpu_particles.emitting = false
	return node


func _create_base_effect() -> Node2D:
	return _create_effect(_particle_effect_script)


func _create_tower_shoot() -> Node2D:
	return _create_effect(_tower_shoot_script)


func _create_impact() -> Node2D:
	return _create_effect(_impact_script)


func _create_enemy_death() -> Node2D:
	return _create_effect(_enemy_death_script)


func _create_placement() -> Node2D:
	return _create_effect(_placement_script)


func _create_upgrade() -> Node2D:
	return _create_effect(_upgrade_script)


# -- Setup / Teardown ----------------------------------------------------------

func before() -> void:
	_load_scripts()


func after() -> void:
	_particle_effect_script = null
	_tower_shoot_script = null
	_impact_script = null
	_enemy_death_script = null
	_placement_script = null
	_upgrade_script = null


# ==============================================================================
# Section 1: ParticleEffect base class
# ==============================================================================

# -- 1.1 spawn() sets position -------------------------------------------------

func test_spawn_sets_position() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	effect.spawn(Vector2(100.0, 200.0))
	assert_vector(effect.position).is_equal(Vector2(100.0, 200.0))


# -- 1.2 spawn() sets modulate color ------------------------------------------

func test_spawn_sets_color() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	effect.spawn(Vector2.ZERO, Color.RED)
	assert_float(effect.modulate.r).is_equal_approx(1.0, 0.01)
	assert_float(effect.modulate.g).is_equal_approx(0.0, 0.01)
	assert_float(effect.modulate.b).is_equal_approx(0.0, 0.01)


# -- 1.3 spawn() default color is WHITE ---------------------------------------

func test_spawn_default_color_is_white() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	effect.spawn(Vector2.ZERO)
	assert_float(effect.modulate.r).is_equal_approx(1.0, 0.01)
	assert_float(effect.modulate.g).is_equal_approx(1.0, 0.01)
	assert_float(effect.modulate.b).is_equal_approx(1.0, 0.01)


# -- 1.4 spawn() starts emission on CPUParticles2D ----------------------------

func test_spawn_starts_emission() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.emitting).is_true()


# -- 1.5 particles are configured as one_shot ---------------------------------

func test_particles_one_shot() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.one_shot).is_true()


# -- 1.6 cleanup_time is set on spawn -----------------------------------------

func test_cleanup_time_set_on_spawn() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	# cleanup_time = lifetime + 0.1
	var expected: float = p.lifetime + 0.1
	assert_float(effect._cleanup_time).is_equal_approx(expected, 0.01)


# -- 1.7 _spawned flag is true after spawn ------------------------------------

func test_spawned_flag_true_after_spawn() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	assert_bool(effect._spawned).is_false()
	effect.spawn(Vector2.ZERO)
	assert_bool(effect._spawned).is_true()


# -- 1.8 _process counts down cleanup time ------------------------------------

func test_process_counts_down_cleanup() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	effect.spawn(Vector2.ZERO)
	var initial: float = effect._cleanup_time
	effect._process(0.1)
	assert_float(effect._cleanup_time).is_equal_approx(initial - 0.1, 0.01)


# -- 1.9 has_method spawn check -----------------------------------------------

func test_base_has_spawn_method() -> void:
	var effect: Node2D = auto_free(_create_base_effect())
	assert_bool(effect.has_method("spawn")).is_true()


# ==============================================================================
# Section 2: TowerShootEffect
# ==============================================================================

# -- 2.1 particle amount in range 8-12 ----------------------------------------

func test_tower_shoot_particle_amount() -> void:
	var effect: Node2D = auto_free(_create_tower_shoot())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.amount >= 8 and p.amount <= 12).is_true()


# -- 2.2 lifetime is short (0.3s) ---------------------------------------------

func test_tower_shoot_lifetime() -> void:
	var effect: Node2D = auto_free(_create_tower_shoot())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_float(p.lifetime).is_equal_approx(0.3, 0.01)


# -- 2.3 element color is applied via spawn -----------------------------------

func test_tower_shoot_element_color() -> void:
	var effect: Node2D = auto_free(_create_tower_shoot())
	var fire_color: Color = ElementMatrix.get_color("fire")
	effect.spawn(Vector2(50.0, 50.0), fire_color)
	assert_float(effect.modulate.r).is_equal_approx(fire_color.r, 0.01)
	assert_float(effect.modulate.g).is_equal_approx(fire_color.g, 0.01)
	assert_float(effect.modulate.b).is_equal_approx(fire_color.b, 0.01)


# -- 2.4 small spread angle ---------------------------------------------------

func test_tower_shoot_small_spread() -> void:
	var effect: Node2D = auto_free(_create_tower_shoot())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.spread <= 45.0).is_true()


# -- 2.5 has spawn method -----------------------------------------------------

func test_tower_shoot_has_spawn() -> void:
	var effect: Node2D = auto_free(_create_tower_shoot())
	assert_bool(effect.has_method("spawn")).is_true()


# ==============================================================================
# Section 3: ImpactEffect
# ==============================================================================

# -- 3.1 particle amount in range 10-15 ---------------------------------------

func test_impact_particle_amount() -> void:
	var effect: Node2D = auto_free(_create_impact())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.amount >= 10 and p.amount <= 15).is_true()


# -- 3.2 lifetime is 0.4s -----------------------------------------------------

func test_impact_lifetime() -> void:
	var effect: Node2D = auto_free(_create_impact())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_float(p.lifetime).is_equal_approx(0.4, 0.01)


# -- 3.3 radial spread (spread = 180 for full circle) -------------------------

func test_impact_radial_spread() -> void:
	var effect: Node2D = auto_free(_create_impact())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_float(p.spread).is_equal_approx(180.0, 0.01)


# -- 3.4 element color applied ------------------------------------------------

func test_impact_element_color() -> void:
	var effect: Node2D = auto_free(_create_impact())
	var ice_color: Color = ElementMatrix.get_color("ice")
	effect.spawn(Vector2(100.0, 100.0), ice_color)
	assert_float(effect.modulate.r).is_equal_approx(ice_color.r, 0.01)
	assert_float(effect.modulate.g).is_equal_approx(ice_color.g, 0.01)
	assert_float(effect.modulate.b).is_equal_approx(ice_color.b, 0.01)


# -- 3.5 has spawn method -----------------------------------------------------

func test_impact_has_spawn() -> void:
	var effect: Node2D = auto_free(_create_impact())
	assert_bool(effect.has_method("spawn")).is_true()


# ==============================================================================
# Section 4: EnemyDeathEffect
# ==============================================================================

# -- 4.1 particle amount in range 15-20 ---------------------------------------

func test_enemy_death_particle_amount() -> void:
	var effect: Node2D = auto_free(_create_enemy_death())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.amount >= 15 and p.amount <= 20).is_true()


# -- 4.2 lifetime is 0.5s -----------------------------------------------------

func test_enemy_death_lifetime() -> void:
	var effect: Node2D = auto_free(_create_enemy_death())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_float(p.lifetime).is_equal_approx(0.5, 0.01)


# -- 4.3 radial burst spread --------------------------------------------------

func test_enemy_death_radial_spread() -> void:
	var effect: Node2D = auto_free(_create_enemy_death())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_float(p.spread).is_equal_approx(180.0, 0.01)


# -- 4.4 default color is white (neutral) -------------------------------------

func test_enemy_death_default_white() -> void:
	var effect: Node2D = auto_free(_create_enemy_death())
	effect.spawn(Vector2(50.0, 50.0))
	assert_float(effect.modulate.r).is_equal_approx(1.0, 0.01)
	assert_float(effect.modulate.g).is_equal_approx(1.0, 0.01)
	assert_float(effect.modulate.b).is_equal_approx(1.0, 0.01)


# -- 4.5 higher initial velocity than tower shoot (bigger burst) ---------------

func test_enemy_death_higher_velocity() -> void:
	var death_effect: Node2D = auto_free(_create_enemy_death())
	death_effect.spawn(Vector2.ZERO)
	var death_p: CPUParticles2D = death_effect.get_node("Particles")

	var shoot_effect: Node2D = auto_free(_create_tower_shoot())
	shoot_effect.spawn(Vector2.ZERO)
	var shoot_p: CPUParticles2D = shoot_effect.get_node("Particles")

	assert_bool(death_p.initial_velocity_max >= shoot_p.initial_velocity_max).is_true()


# ==============================================================================
# Section 5: PlacementEffect
# ==============================================================================

# -- 5.1 particle amount in range 8-10 ----------------------------------------

func test_placement_particle_amount() -> void:
	var effect: Node2D = auto_free(_create_placement())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.amount >= 8 and p.amount <= 10).is_true()


# -- 5.2 lifetime is 0.4s -----------------------------------------------------

func test_placement_lifetime() -> void:
	var effect: Node2D = auto_free(_create_placement())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_float(p.lifetime).is_equal_approx(0.4, 0.01)


# -- 5.3 earth-toned color (brownish/tan) -------------------------------------

func test_placement_earth_tone_color() -> void:
	var effect: Node2D = auto_free(_create_placement())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.color.r >= 0.4).is_true()
	assert_bool(p.color.b <= 0.5).is_true()


# -- 5.4 upward drift (direction.y < 0) ---------------------------------------

func test_placement_upward_drift() -> void:
	var effect: Node2D = auto_free(_create_placement())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	var has_upward: bool = p.gravity.y < 0.0 or p.direction.y < 0.0
	assert_bool(has_upward).is_true()


# -- 5.5 spawn sets position --------------------------------------------------

func test_placement_sets_position() -> void:
	var effect: Node2D = auto_free(_create_placement())
	effect.spawn(Vector2(320.0, 480.0))
	assert_vector(effect.position).is_equal(Vector2(320.0, 480.0))


# ==============================================================================
# Section 6: UpgradeEffect
# ==============================================================================

# -- 6.1 particle amount in range 12-16 ---------------------------------------

func test_upgrade_particle_amount() -> void:
	var effect: Node2D = auto_free(_create_upgrade())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.amount >= 12 and p.amount <= 16).is_true()


# -- 6.2 lifetime is 0.6s -----------------------------------------------------

func test_upgrade_lifetime() -> void:
	var effect: Node2D = auto_free(_create_upgrade())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_float(p.lifetime).is_equal_approx(0.6, 0.01)


# -- 6.3 gold/yellow color ----------------------------------------------------

func test_upgrade_gold_color() -> void:
	var effect: Node2D = auto_free(_create_upgrade())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	assert_bool(p.color.r >= 0.8).is_true()
	assert_bool(p.color.g >= 0.7).is_true()
	assert_bool(p.color.b <= 0.4).is_true()


# -- 6.4 upward motion --------------------------------------------------------

func test_upgrade_upward_motion() -> void:
	var effect: Node2D = auto_free(_create_upgrade())
	effect.spawn(Vector2.ZERO)
	var p: CPUParticles2D = effect.get_node("Particles")
	var has_upward: bool = p.gravity.y < 0.0 or p.direction.y < 0.0
	assert_bool(has_upward).is_true()


# -- 6.5 medium lifetime is longer than shoot effect ---------------------------

func test_upgrade_longer_than_shoot() -> void:
	var upgrade: Node2D = auto_free(_create_upgrade())
	upgrade.spawn(Vector2.ZERO)
	var upgrade_p: CPUParticles2D = upgrade.get_node("Particles")

	var shoot: Node2D = auto_free(_create_tower_shoot())
	shoot.spawn(Vector2.ZERO)
	var shoot_p: CPUParticles2D = shoot.get_node("Particles")

	assert_bool(upgrade_p.lifetime > shoot_p.lifetime).is_true()


# ==============================================================================
# Section 7: Integration with ElementMatrix colors
# ==============================================================================

# -- 7.1 fire element color matches ElementMatrix -----------------------------

func test_fire_element_color_via_element_matrix() -> void:
	var effect: Node2D = auto_free(_create_impact())
	var color: Color = ElementMatrix.get_color("fire")
	effect.spawn(Vector2.ZERO, color)
	assert_float(effect.modulate.r).is_equal_approx(color.r, 0.01)
	assert_float(effect.modulate.g).is_equal_approx(color.g, 0.01)
	assert_float(effect.modulate.b).is_equal_approx(color.b, 0.01)


# -- 7.2 lightning element color matches ElementMatrix -------------------------

func test_lightning_element_color_via_element_matrix() -> void:
	var effect: Node2D = auto_free(_create_tower_shoot())
	var color: Color = ElementMatrix.get_color("lightning")
	effect.spawn(Vector2.ZERO, color)
	assert_float(effect.modulate.r).is_equal_approx(color.r, 0.01)
	assert_float(effect.modulate.g).is_equal_approx(color.g, 0.01)
	assert_float(effect.modulate.b).is_equal_approx(color.b, 0.01)


# -- 7.3 all 6 elements produce valid colors ----------------------------------

func test_all_element_colors_valid() -> void:
	for element: String in ElementMatrix.ELEMENTS:
		var color: Color = ElementMatrix.get_color(element)
		var effect: Node2D = auto_free(_create_impact())
		effect.spawn(Vector2.ZERO, color)
		var brightness: float = color.r + color.g + color.b
		assert_bool(brightness > 0.0).override_failure_message(
			"Element '%s' produced a black color" % element
		).is_true()
