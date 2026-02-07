extends GdUnitTestSuite

## Unit tests for StatusEffect (RefCounted).
## Covers: construction, tick damage, expiration, and type_to_string.


# -- Helpers -------------------------------------------------------------------

func _burn(duration: float = 5.0, dps: float = 10.0) -> StatusEffect:
	return StatusEffect.new(StatusEffect.Type.BURN, duration, dps)


# -- Construction --------------------------------------------------------------

func test_burn_creation() -> void:
	var fx: StatusEffect = _burn(3.0, 15.0)
	assert_int(fx.type).is_equal(StatusEffect.Type.BURN)
	assert_float(fx.duration).is_equal(3.0)
	assert_float(fx.value).is_equal(15.0)
	assert_float(fx.elapsed).is_equal(0.0)


# -- Burn Tick Damage ----------------------------------------------------------

func test_burn_tick_returns_damage_per_second() -> void:
	var fx: StatusEffect = _burn(5.0, 20.0)
	var dmg: float = fx.tick(1.0)
	assert_float(dmg).is_equal(20.0)


func test_burn_tick_partial_no_damage() -> void:
	var fx: StatusEffect = _burn(5.0, 20.0)
	var dmg: float = fx.tick(0.5)
	assert_float(dmg).is_equal(0.0)


func test_burn_tick_accumulates() -> void:
	var fx: StatusEffect = _burn(5.0, 20.0)
	var dmg1: float = fx.tick(0.6)
	assert_float(dmg1).is_equal(0.0)
	var dmg2: float = fx.tick(0.6)
	# 0.6 + 0.6 = 1.2 >= 1.0, so damage fires on the second tick
	assert_float(dmg2).is_equal(20.0)


# -- Non-Burn Tick Returns Zero ------------------------------------------------

func test_slow_tick_returns_zero() -> void:
	var fx := StatusEffect.new(StatusEffect.Type.SLOW, 3.0, 0.3)
	assert_float(fx.tick(1.0)).is_equal(0.0)


func test_freeze_tick_returns_zero() -> void:
	var fx := StatusEffect.new(StatusEffect.Type.FREEZE, 2.0, 1.0)
	assert_float(fx.tick(1.0)).is_equal(0.0)


func test_stun_tick_returns_zero() -> void:
	var fx := StatusEffect.new(StatusEffect.Type.STUN, 1.5, 1.0)
	assert_float(fx.tick(1.0)).is_equal(0.0)


func test_wet_tick_returns_zero() -> void:
	var fx := StatusEffect.new(StatusEffect.Type.WET, 4.0, 1.0)
	assert_float(fx.tick(1.0)).is_equal(0.0)


# -- Expiration ----------------------------------------------------------------

func test_is_expired_false_while_active() -> void:
	var fx: StatusEffect = _burn(3.0, 10.0)
	fx.tick(1.0)
	assert_bool(fx.is_expired()).is_false()


func test_is_expired_true_when_depleted() -> void:
	var fx: StatusEffect = _burn(1.0, 10.0)
	fx.tick(1.0)
	assert_bool(fx.is_expired()).is_true()


func test_is_expired_true_when_overshot() -> void:
	var fx: StatusEffect = _burn(1.0, 10.0)
	fx.tick(2.0)
	assert_bool(fx.is_expired()).is_true()


# -- type_to_string ------------------------------------------------------------

func test_type_to_string_all_types() -> void:
	assert_str(StatusEffect.type_to_string(StatusEffect.Type.BURN)).is_equal("burn")
	assert_str(StatusEffect.type_to_string(StatusEffect.Type.SLOW)).is_equal("slow")
	assert_str(StatusEffect.type_to_string(StatusEffect.Type.FREEZE)).is_equal("freeze")
	assert_str(StatusEffect.type_to_string(StatusEffect.Type.STUN)).is_equal("stun")
	assert_str(StatusEffect.type_to_string(StatusEffect.Type.WET)).is_equal("wet")
