class_name DraftPickPanel
extends Control

## Full-screen overlay for Draft mode element selection.
## Shows element cards when DraftManager emits draft_pick_available.
## Pauses the game while open, resumes after a pick is made.
## process_mode is PROCESS_MODE_WHEN_PAUSED so it remains interactive while paused.

# Element -> base tower name mapping (tier 1 only, avoids runtime resource scanning)
const ELEMENT_TOWERS: Dictionary = {
	"fire": ["Flame Spire"],
	"water": ["Tidal Obelisk"],
	"earth": ["Stone Bastion"],
	"wind": ["Gale Tower"],
	"lightning": ["Thunder Pylon"],
	"ice": ["Frost Sentinel"],
}

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var cards_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/CardsContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	DraftManager.draft_pick_available.connect(_on_draft_pick_available)


func _on_draft_pick_available(choices: Array[String]) -> void:
	show_choices(choices)


## Display element cards for the given choices and pause the game.
func show_choices(choices: Array[String]) -> void:
	_clear_cards()
	for element: String in choices:
		var card: Button = _create_element_card(element)
		cards_container.add_child(card)
	GameManager.pause()
	visible = true


## Hide the panel, clear cards, and unpause the game.
func hide_panel() -> void:
	visible = false
	_clear_cards()
	GameManager.unpause()


## Returns the list of tier-1 base tower names for the given element.
func _get_towers_for_element(element: String) -> Array[String]:
	if element in ELEMENT_TOWERS:
		var result: Array[String] = []
		for tower_name: String in ELEMENT_TOWERS[element]:
			result.append(tower_name)
		return result
	return []


func _create_element_card(element: String) -> Button:
	var card := Button.new()
	card.set_meta("element", element)
	card.custom_minimum_size = Vector2(200, 280)

	# Build card text: capitalized name + tower list
	var display_name: String = element.capitalize()
	var towers: Array[String] = _get_towers_for_element(element)
	var tower_text: String = ""
	if towers.size() > 0:
		tower_text = "\n\nTowers:\n" + "\n".join(towers)
	card.text = display_name + tower_text

	# Apply element color as background
	var color: Color = ElementMatrix.get_color(element)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("normal", style)

	# Hover style: slightly brighter
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("hover", hover_style)

	# Pressed style: slightly darker
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.2)
	pressed_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("pressed", pressed_style)

	card.pressed.connect(_on_card_pressed.bind(element))
	return card


func _on_card_pressed(element: String) -> void:
	DraftManager.pick_element(element)
	visible = false
	GameManager.unpause()
	# Defer card cleanup so the button that emitted the signal is not freed
	# while still locked during emission.
	call_deferred("_clear_cards")


## Remove all cards from the container and free them immediately.
func _clear_cards() -> void:
	for child: Node in cards_container.get_children():
		cards_container.remove_child(child)
		child.free()
