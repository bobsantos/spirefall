class_name DraftPickPanel
extends Control

## Full-screen overlay for Draft mode element selection.
## Shows element cards when DraftManager emits draft_pick_available.
## Pauses the game while open, resumes after all picks for the round are made.
## process_mode is PROCESS_MODE_WHEN_PAUSED so it remains interactive while paused.
## Supports multi-pick rounds: when pick_count == 2, the player selects 2 cards
## before the panel closes.

# Element -> base tower name mapping (tier 1 only, avoids runtime resource scanning)
const ELEMENT_TOWERS: Dictionary = {
	"fire": ["Flame Spire"],
	"water": ["Tidal Obelisk"],
	"earth": ["Stone Bastion"],
	"wind": ["Gale Tower"],
	"lightning": ["Thunder Pylon"],
	"ice": ["Frost Sentinel"],
}

# Tower name -> sprite filename mapping
const TOWER_SPRITES: Dictionary = {
	"Flame Spire": "flame_spire",
	"Tidal Obelisk": "tidal_obelisk",
	"Stone Bastion": "stone_bastion",
	"Gale Tower": "gale_tower",
	"Thunder Pylon": "thunder_pylon",
	"Frost Sentinel": "frost_sentinel",
}

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var cards_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/CardsContainer

var _picks_needed: int = 1
var _picks_made: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	DraftManager.draft_pick_available.connect(_on_draft_pick_available)
	DraftManager.draft_started.connect(_on_draft_started)


func _on_draft_started(_starting_element: String) -> void:
	# First pick handled by draft_pick_available emitted right after draft_started
	pass


func _on_draft_pick_available(choices: Array[String], pick_count: int) -> void:
	_picks_needed = pick_count
	_picks_made = 0
	if DraftManager.drafted_elements.size() == 0:
		title_label.text = "Choose Your Starting Element"
	elif pick_count >= 2:
		title_label.text = "Choose 2 Elements"
	else:
		title_label.text = "Draft an Element"
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
	card.text = ""

	var color: Color = ElementMatrix.get_color(element)

	# Darkened background with element color border for readability
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.6)
	style.set_corner_radius_all(8)
	style.border_color = color
	style.set_border_width_all(3)
	card.add_theme_stylebox_override("normal", style)

	# Hover style: slightly brighter background
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = color.darkened(0.4)
	hover_style.set_corner_radius_all(8)
	hover_style.border_color = color.lightened(0.2)
	hover_style.set_border_width_all(3)
	card.add_theme_stylebox_override("hover", hover_style)

	# Pressed style: darker background
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.7)
	pressed_style.set_corner_radius_all(8)
	pressed_style.border_color = color
	pressed_style.set_border_width_all(3)
	card.add_theme_stylebox_override("pressed", pressed_style)

	# White text for contrast
	card.add_theme_color_override("font_color", Color.WHITE)

	# Build card content: element name, tower sprite, tower name
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# Element name label
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = element.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Tower sprite and name for the first tower of this element
	var towers: Array[String] = _get_towers_for_element(element)
	if towers.size() > 0:
		var tower_name: String = towers[0]

		# Tower sprite
		var sprite_name: String = TOWER_SPRITES.get(tower_name, "")
		if sprite_name != "":
			var tex_path: String = "res://assets/sprites/towers/%s.png" % sprite_name
			var tex: Texture2D = load(tex_path)
			if tex:
				var tex_rect := TextureRect.new()
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tex_rect.texture = tex
				tex_rect.custom_minimum_size = Vector2(64, 64)
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				vbox.add_child(tex_rect)

		# Tower name label
		var tower_label := Label.new()
		tower_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tower_label.text = tower_name
		tower_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tower_label.add_theme_color_override("font_color", Color.WHITE)
		tower_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(tower_label)

	card.add_child(vbox)
	card.pressed.connect(_on_card_pressed.bind(element, card))
	return card


func _on_card_pressed(element: String, card: Button) -> void:
	DraftManager.pick_element(element)
	_picks_made += 1

	if _picks_needed >= 2 and _picks_made < _picks_needed:
		# Multi-pick: mark card as selected, keep panel open
		_mark_card_selected(card, element)
		card.disabled = true
	else:
		# Single pick or all picks done: close panel
		visible = false
		GameManager.unpause()
		# Defer card cleanup so the button that emitted the signal is not freed
		# while still locked during emission.
		call_deferred("_clear_cards")


## Apply a "selected" visual to a card: brighten border, lighten bg, add checkmark.
func _mark_card_selected(card: Button, element: String) -> void:
	var color: Color = ElementMatrix.get_color(element)
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = color.darkened(0.3)
	selected_style.set_corner_radius_all(8)
	selected_style.border_color = color.lightened(0.4)
	selected_style.set_border_width_all(4)
	card.add_theme_stylebox_override("normal", selected_style)
	card.add_theme_stylebox_override("disabled", selected_style)

	# Add a checkmark overlay
	var check_label := Label.new()
	check_label.name = "CheckMark"
	check_label.text = "Selected"
	check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_label.add_theme_color_override("font_color", Color.WHITE)
	check_label.add_theme_font_size_override("font_size", 14)
	check_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add to the card's VBox if available, otherwise directly to card
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer if card.get_child_count() > 0 else null
	if vbox:
		vbox.add_child(check_label)
	else:
		card.add_child(check_label)


## Remove all cards from the container and free them immediately.
func _clear_cards() -> void:
	for child: Node in cards_container.get_children():
		cards_container.remove_child(child)
		child.free()
