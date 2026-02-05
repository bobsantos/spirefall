class_name EconomyManagerClass
extends Node

## Tracks gold, income, interest, and all economic transactions.

signal gold_changed(new_amount: int)
signal insufficient_funds(cost: int)

const STARTING_GOLD: int = 100
const INTEREST_RATE: float = 0.05  # 5% per 100 gold
const INTEREST_CAP: float = 0.25  # Max 25% return
const INTEREST_INTERVAL: int = 100  # Per 100 gold banked

var gold: int = STARTING_GOLD


func _ready() -> void:
	gold = STARTING_GOLD


func reset() -> void:
	gold = STARTING_GOLD
	gold_changed.emit(gold)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		insufficient_funds.emit(amount)
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func can_afford(amount: int) -> bool:
	return gold >= amount


func apply_interest() -> void:
	var interest_tiers: int = gold / INTEREST_INTERVAL
	var interest_pct: float = minf(interest_tiers * INTEREST_RATE, INTEREST_CAP)
	var interest_gold: int = int(gold * interest_pct)
	if interest_gold > 0:
		add_gold(interest_gold)


func calculate_wave_bonus(wave_number: int, enemies_leaked: int) -> int:
	var base_bonus: int = 10 + (wave_number * 3)
	if enemies_leaked == 0:
		base_bonus = int(base_bonus * 1.25)  # No-leak bonus
	return base_bonus
