extends GdUnitTestSuite

## Unit tests for EconomyManager autoload.
## Covers: gold transactions, interest calculation, wave bonus formula, and signals.


# -- Setup / Teardown ----------------------------------------------------------

func before_test() -> void:
	EconomyManager.reset()


# -- Starting State ------------------------------------------------------------

func test_starting_gold_is_100() -> void:
	assert_int(EconomyManager.gold).is_equal(100)


func test_reset_restores_starting_gold() -> void:
	EconomyManager.spend_gold(50)
	assert_int(EconomyManager.gold).is_equal(50)
	EconomyManager.reset()
	assert_int(EconomyManager.gold).is_equal(100)


# -- add_gold / spend_gold / can_afford ----------------------------------------

func test_add_gold_increases_balance() -> void:
	EconomyManager.add_gold(50)
	assert_int(EconomyManager.gold).is_equal(150)


func test_spend_gold_reduces_balance() -> void:
	var result: bool = EconomyManager.spend_gold(30)
	assert_bool(result).is_true()
	assert_int(EconomyManager.gold).is_equal(70)


func test_spend_gold_fails_when_insufficient() -> void:
	var result: bool = EconomyManager.spend_gold(200)
	assert_bool(result).is_false()
	assert_int(EconomyManager.gold).is_equal(100)


func test_can_afford_true_when_enough() -> void:
	assert_bool(EconomyManager.can_afford(100)).is_true()


func test_can_afford_false_when_not_enough() -> void:
	assert_bool(EconomyManager.can_afford(101)).is_false()


func test_can_afford_exact_amount() -> void:
	# Edge case: exact balance should return true
	assert_bool(EconomyManager.can_afford(100)).is_true()


# -- Interest Calculation ------------------------------------------------------
# Interest formula: tiers = gold / 100, pct = min(tiers * 0.05, 0.25),
#                   interest = int(gold * pct)

func test_interest_at_100_gold() -> void:
	# 100g -> 1 tier -> 5% -> int(100 * 0.05) = 5
	EconomyManager.gold = 100
	EconomyManager.apply_interest()
	assert_int(EconomyManager.gold).is_equal(105)


func test_interest_at_500_gold() -> void:
	# 500g -> 5 tiers -> 25% (cap) -> int(500 * 0.25) = 125
	EconomyManager.gold = 500
	EconomyManager.apply_interest()
	assert_int(EconomyManager.gold).is_equal(625)


func test_interest_at_600_gold_capped() -> void:
	# 600g -> 6 tiers -> capped at 25% -> int(600 * 0.25) = 150
	EconomyManager.gold = 600
	EconomyManager.apply_interest()
	assert_int(EconomyManager.gold).is_equal(750)


func test_interest_at_99_gold_zero() -> void:
	# 99g -> 0 tiers -> 0% -> +0
	EconomyManager.gold = 99
	EconomyManager.apply_interest()
	assert_int(EconomyManager.gold).is_equal(99)


func test_interest_at_250_gold() -> void:
	# 250g -> 2 tiers -> 10% -> int(250 * 0.10) = 25
	EconomyManager.gold = 250
	EconomyManager.apply_interest()
	assert_int(EconomyManager.gold).is_equal(275)


# -- Wave Bonus Formula --------------------------------------------------------
# Formula: base = 10 + (wave * 3), no-leak bonus = int(base * 1.25)

func test_wave_bonus_base_formula() -> void:
	# Wave 5, 1 leak: 10 + (5 * 3) = 25, no no-leak bonus
	var bonus: int = EconomyManager.calculate_wave_bonus(5, 1)
	assert_int(bonus).is_equal(25)


func test_wave_bonus_no_leak_multiplier() -> void:
	# Wave 5, 0 leaks: 25 * 1.25 = 31.25 -> int = 31
	var bonus: int = EconomyManager.calculate_wave_bonus(5, 0)
	assert_int(bonus).is_equal(31)


func test_wave_bonus_wave_1() -> void:
	# Wave 1, 0 leaks: (10 + 3) * 1.25 = 16.25 -> int = 16
	var bonus: int = EconomyManager.calculate_wave_bonus(1, 0)
	assert_int(bonus).is_equal(16)


# -- Signals -------------------------------------------------------------------

func test_gold_changed_signal_on_add() -> void:
	monitor_signals(EconomyManager, false)
	EconomyManager.add_gold(25)
	await assert_signal(EconomyManager).wait_until(500).is_emitted("gold_changed", 125)


func test_insufficient_funds_signal() -> void:
	monitor_signals(EconomyManager, false)
	EconomyManager.spend_gold(999)
	await assert_signal(EconomyManager).wait_until(500).is_emitted("insufficient_funds", 999)
