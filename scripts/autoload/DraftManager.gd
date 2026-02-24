class_name DraftManagerClass
extends Node

## Manages Draft mode element selection. Players start with 1 random element
## and draft 2 more at waves 5 and 10 (configurable via DRAFT_WAVES).

const STARTING_ELEMENTS: int = 1
const DRAFT_WAVES: Array[int] = [5, 10]
const CHOICES_PER_PICK: int = 3

signal draft_started(starting_element: String)
signal draft_pick_available(choices: Array[String])
signal element_drafted(element: String)

var drafted_elements: Array[String] = []
var is_draft_active: bool = false
var picks_remaining: int = 0


func _ready() -> void:
	GameManager.wave_completed.connect(_on_wave_completed)


func start_draft() -> void:
	drafted_elements.clear()
	is_draft_active = true
	picks_remaining = len(DRAFT_WAVES)
	# Randomly assign one starting element
	var available: Array[String] = ElementMatrix.ELEMENTS.duplicate()
	available.shuffle()
	var starting: String = available[0]
	drafted_elements.append(starting)
	draft_started.emit(starting)


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


func reset() -> void:
	drafted_elements.clear()
	is_draft_active = false
	picks_remaining = 0


func _on_wave_completed(wave_number: int) -> void:
	if not is_draft_active:
		return
	if picks_remaining <= 0:
		return
	if wave_number in DRAFT_WAVES:
		var choices: Array[String] = get_draft_choices()
		draft_pick_available.emit(choices)
