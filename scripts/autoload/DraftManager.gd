class_name DraftManagerClass
extends Node

## Manages Draft mode element selection. Players draft 4 elements across 3 rounds:
## - Round 0 (game start): Choose 1 from 3 random elements
## - Round 1 (wave 5): Choose 1 from 3 remaining elements
## - Round 2 (wave 10): Choose 2 from 3 remaining elements
## Total: 4 elements drafted, 2 always locked out.

const CHOICES_PER_PICK: int = 3

# Each entry is [wave_trigger, picks_to_make].
# wave 0 means "at game start".
const DRAFT_ROUNDS: Array = [[0, 1], [5, 1], [10, 2]]

signal draft_started(starting_element: String)
signal draft_pick_available(choices: Array[String], pick_count: int)
signal element_drafted(element: String)

var drafted_elements: Array[String] = []
var is_draft_active: bool = false
var picks_remaining: int = 0

var _current_round: int = 0
var _picks_this_round: int = 0
var _picks_needed_this_round: int = 0


func _ready() -> void:
	GameManager.wave_completed.connect(_on_wave_completed)


func start_draft() -> void:
	drafted_elements.clear()
	is_draft_active = true
	# Total individual picks across all rounds: 1 + 1 + 2 = 4
	picks_remaining = 4
	_current_round = 0
	_picks_this_round = 0
	_picks_needed_this_round = 0
	draft_started.emit("")
	# Start round 0 (game-start pick)
	_start_round(0)


func get_draft_choices() -> Array[String]:
	var available: Array[String] = []
	for el: String in ElementMatrix.ELEMENTS:
		if el not in drafted_elements:
			available.append(el)
	available.shuffle()
	if available.size() <= CHOICES_PER_PICK:
		return available
	return available.slice(0, CHOICES_PER_PICK)


func pick_element(element: String) -> void:
	if picks_remaining <= 0:
		return
	if element in drafted_elements:
		return
	if element not in ElementMatrix.ELEMENTS:
		return
	drafted_elements.append(element)
	picks_remaining -= 1
	_picks_this_round += 1
	element_drafted.emit(element)


func is_tower_available(tower_data: TowerData) -> bool:
	if not is_draft_active:
		return true
	# Fusion and legendary towers: check all fusion_elements
	if tower_data.fusion_elements.size() > 0:
		for el: String in tower_data.fusion_elements:
			if el not in drafted_elements:
				return false
		return true
	# Base towers: check the element field
	return tower_data.element in drafted_elements


func is_round_complete() -> bool:
	return _picks_this_round >= _picks_needed_this_round


func reset() -> void:
	drafted_elements.clear()
	is_draft_active = false
	picks_remaining = 0
	_current_round = 0
	_picks_this_round = 0
	_picks_needed_this_round = 0


func _start_round(round_index: int) -> void:
	if round_index >= DRAFT_ROUNDS.size():
		return
	_current_round = round_index
	_picks_this_round = 0
	_picks_needed_this_round = DRAFT_ROUNDS[round_index][1]
	var choices: Array[String] = get_draft_choices()
	draft_pick_available.emit(choices, _picks_needed_this_round)


func _on_wave_completed(wave_number: int) -> void:
	if not is_draft_active:
		return
	if picks_remaining <= 0:
		return
	# Check if any future round matches this wave trigger
	for i: int in range(DRAFT_ROUNDS.size()):
		if DRAFT_ROUNDS[i][0] == wave_number and i > _current_round:
			_start_round(i)
			return
