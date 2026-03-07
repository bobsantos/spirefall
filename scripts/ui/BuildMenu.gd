extends Control

## Bottom panel: scrollable row of tower build buttons grouped by element.
## Each button shows tower name, cost, element color, sprite thumbnail, and
## provides a tooltip with stats on hover.
## When DraftManager is active, only towers whose elements have been drafted
## are shown. A draft indicator at the top displays currently drafted elements.

signal tower_build_selected(tower_data: TowerData)

@onready var button_container: HBoxContainer = $ScrollContainer/HBoxContainer

var _tower_buttons: Array[Button] = []
var _available_towers: Array[TowerData] = []
var _draft_indicator: HBoxContainer
var _cancel_button: Button

# Canonical element order for build menu button layout
const ELEMENT_ORDER: Array[String] = ["fire", "water", "earth", "wind", "lightning", "ice"]

# Element colors used for button tinting, separators, and icon circles
const ELEMENT_COLORS: Dictionary = {
	"fire": Color(0.9, 0.25, 0.15),
	"water": Color(0.2, 0.5, 0.95),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.8, 0.35),
	"lightning": Color(0.95, 0.85, 0.15),
	"ice": Color(0.3, 0.85, 0.9),
}

# Softer tint for button backgrounds (mixed with neutral dark)
const ELEMENT_BG_COLORS: Dictionary = {
	"fire": Color(0.35, 0.12, 0.1, 0.85),
	"water": Color(0.1, 0.18, 0.35, 0.85),
	"earth": Color(0.25, 0.18, 0.1, 0.85),
	"wind": Color(0.12, 0.28, 0.14, 0.85),
	"lightning": Color(0.3, 0.28, 0.08, 0.85),
	"ice": Color(0.1, 0.25, 0.3, 0.85),
}


func _ready() -> void:
	UIManager.register_build_menu(self)
	_load_available_towers()
	_create_draft_indicator()
	_create_buttons()
	_create_cancel_button()
	if UIManager.is_mobile():
		_apply_mobile_sizing()
	_connect_draft_signals()
	UIManager.build_requested.connect(_on_placement_started)
	UIManager.placement_ended.connect(_on_placement_ended)


func _load_available_towers() -> void:
	# Load all tier-1 base towers by explicit path list.
	# DirAccess.open() does not work in web exports (files are packed in .pck),
	# so we list tower resource paths statically.
	var tower_paths: Array[String] = [
		"res://resources/towers/flame_spire.tres",
		"res://resources/towers/tidal_obelisk.tres",
		"res://resources/towers/stone_bastion.tres",
		"res://resources/towers/gale_tower.tres",
		"res://resources/towers/thunder_pylon.tres",
		"res://resources/towers/frost_sentinel.tres",
	]
	for path: String in tower_paths:
		var tower: TowerData = load(path)
		if tower and tower.tier == 1:
			_available_towers.append(tower)
	# Sort by canonical element order for consistent button layout
	_available_towers.sort_custom(func(a: TowerData, b: TowerData) -> bool:
		return ELEMENT_ORDER.find(a.element) < ELEMENT_ORDER.find(b.element)
	)


func _create_draft_indicator() -> void:
	_draft_indicator = HBoxContainer.new()
	_draft_indicator.name = "DraftIndicator"
	_draft_indicator.add_theme_constant_override("separation", 4)
	_draft_indicator.visible = false
	button_container.add_child(_draft_indicator)
	_update_draft_indicator()


func _update_draft_indicator() -> void:
	# Clear existing indicator children
	for child: Node in _draft_indicator.get_children():
		child.free()

	if not DraftManager.is_draft_active:
		_draft_indicator.visible = false
		return

	_draft_indicator.visible = true

	# "Draft:" label
	var label := Label.new()
	label.text = "Draft:"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_indicator.add_child(label)

	# Colored dots for each drafted element
	var dots_hbox := HBoxContainer.new()
	dots_hbox.add_theme_constant_override("separation", 2)
	dots_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for el: String in DraftManager.drafted_elements:
		var dot := _create_element_icon(el, 6)
		dots_hbox.add_child(dot)
	_draft_indicator.add_child(dots_hbox)


func _create_buttons() -> void:
	for tower: TowerData in _available_towers:
		var btn := _create_tower_button(tower)
		button_container.add_child(btn)
		_tower_buttons.append(btn)

	_refresh_draft_filter()



func _create_tower_button(tower: TowerData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 64)
	btn.clip_text = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_tower_selected.bind(tower))

	# Build the button content as an HBoxContainer child
	# Left side: tower sprite thumbnail; Right side: name + cost + element dot
	var hbox := HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	btn.add_child(hbox)

	# Tower sprite thumbnail
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(32, 32)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture_name: String = tower.tower_name.to_lower().replace(" ", "_")
	var texture_path: String = "res://assets/sprites/towers/%s.png" % texture_name
	var tex: Texture2D = load(texture_path) if ResourceLoader.exists(texture_path) else null
	if tex:
		tex_rect.texture = tex
	hbox.add_child(tex_rect)

	# Right side: VBox with name, cost, and element dot
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)

	var name_label := Label.new()
	name_label.text = tower.tower_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_label)

	# Cost row with a small element dot
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override("separation", 3)

	var dot := _create_element_icon(tower.element, 6)
	cost_row.add_child(dot)

	var cost_label := Label.new()
	cost_label.text = "%dg" % tower.cost
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(cost_label)

	vbox.add_child(cost_row)
	hbox.add_child(vbox)

	# Element-colored background via a StyleBoxFlat override
	var style_normal := StyleBoxFlat.new()
	var bg_color: Color = ELEMENT_BG_COLORS.get(tower.element, Color(0.2, 0.2, 0.2, 0.85))
	style_normal.bg_color = bg_color
	style_normal.border_color = ELEMENT_COLORS.get(tower.element, Color.WHITE)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style_normal)

	# Hover style: slightly brighter
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.15)
	style_hover.border_color = ELEMENT_COLORS.get(tower.element, Color.WHITE).lightened(0.2)
	btn.add_theme_stylebox_override("hover", style_hover)

	# Pressed style: darker
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# Disabled style: desaturated
	var style_disabled := style_normal.duplicate()
	style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	style_disabled.border_color = Color(0.4, 0.4, 0.4, 0.5)
	btn.add_theme_stylebox_override("disabled", style_disabled)

	# Tooltip with tower stats
	btn.tooltip_text = _build_tooltip(tower)

	return btn


func _create_element_icon(element: String, radius: int) -> ColorRect:
	# Small colored square as element indicator (approximates a dot)
	var icon := ColorRect.new()
	icon.color = ELEMENT_COLORS.get(element, Color.WHITE)
	icon.custom_minimum_size = Vector2(radius * 2, radius * 2)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _build_tooltip(tower: TowerData) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(tower.tower_name)
	lines.append("Element: %s" % tower.element.capitalize())
	lines.append("Damage: %d" % tower.damage)
	lines.append("Speed: %.1f/s" % tower.attack_speed)
	lines.append("Range: %d cells" % tower.range_cells)
	lines.append("Cost: %dg" % tower.cost)
	if tower.special_description != "":
		lines.append("Special: %s" % tower.special_description)
	return "\n".join(lines)


func _on_tower_selected(tower_data: TowerData) -> void:
	AudioManager.play_sfx("ui_click")
	UIManager.request_build(tower_data)
	tower_build_selected.emit(tower_data)


func _create_cancel_button() -> void:
	_cancel_button = Button.new()
	_cancel_button.text = "X Cancel"
	_cancel_button.focus_mode = Control.FOCUS_NONE
	_cancel_button.custom_minimum_size = Vector2(80, 64)

	# Red-tinted style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.12, 0.1, 0.9)
	style.border_color = Color(1.0, 0.3, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	_cancel_button.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate()
	style_hover.bg_color = Color(0.6, 0.15, 0.12, 0.95)
	_cancel_button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style.duplicate()
	style_pressed.bg_color = Color(0.35, 0.08, 0.06, 0.9)
	_cancel_button.add_theme_stylebox_override("pressed", style_pressed)

	_cancel_button.add_theme_font_size_override("font_size", 13)
	_cancel_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8))
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_cancel_button.visible = false
	button_container.add_child(_cancel_button)
	# Move to front so it's the first visible button
	button_container.move_child(_cancel_button, 0)


func _apply_mobile_sizing() -> void:
	## Increase all build menu element sizes for mobile touch targets.
	# Panel height
	custom_minimum_size.y = UIManager.MOBILE_BUILD_MENU_HEIGHT
	offset_top = -float(UIManager.MOBILE_BUILD_MENU_HEIGHT)

	# HBoxContainer separation for easier targeting
	button_container.add_theme_constant_override("separation", 10)

	# Tower buttons
	for btn: Button in _tower_buttons:
		btn.custom_minimum_size = UIManager.MOBILE_TOWER_BUTTON_MIN
		_apply_mobile_button_content(btn)

	# Cancel button
	_cancel_button.custom_minimum_size = Vector2(130, 100)

	# Draft indicator dots
	_apply_mobile_draft_dots()


func _apply_mobile_button_content(btn: Button) -> void:
	## Increase font sizes, element dot, and thumbnail within a tower button.
	for child: Node in btn.get_children():
		if child is HBoxContainer:
			var hbox: HBoxContainer = child as HBoxContainer
			for hbox_child: Node in hbox.get_children():
				if hbox_child is TextureRect:
					# Tower sprite thumbnail: 32x32 -> 40x40
					hbox_child.custom_minimum_size = Vector2(40, 40)
				elif hbox_child is VBoxContainer:
					var vbox: VBoxContainer = hbox_child as VBoxContainer
					for vbox_child: Node in vbox.get_children():
						if vbox_child is Label:
							# Name label: 11 -> 14
							vbox_child.add_theme_font_size_override("font_size", 14)
						elif vbox_child is HBoxContainer:
							# Cost row
							var cost_row: HBoxContainer = vbox_child as HBoxContainer
							for cost_child: Node in cost_row.get_children():
								if cost_child is ColorRect:
									# Element dot: radius 6 -> 8 (diameter 12 -> 16)
									cost_child.custom_minimum_size = Vector2(16, 16)
								elif cost_child is Label:
									# Cost label: 10 -> 13
									cost_child.add_theme_font_size_override("font_size", 13)


func _apply_mobile_draft_dots() -> void:
	## Increase draft indicator dot sizes for mobile.
	for child: Node in _draft_indicator.get_children():
		if child is HBoxContainer:
			for dot_child: Node in child.get_children():
				if dot_child is ColorRect:
					dot_child.custom_minimum_size = Vector2(16, 16)


func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	UIManager.cancel_placement()


func _on_placement_started(_tower_data: TowerData) -> void:
	_cancel_button.visible = true


func _on_placement_ended() -> void:
	_cancel_button.visible = false


## Connect to DraftManager signals for live updates when draft starts or new elements are drafted.
func _connect_draft_signals() -> void:
	if not DraftManager.draft_started.is_connected(_on_draft_started):
		DraftManager.draft_started.connect(_on_draft_started)
	if not DraftManager.element_drafted.is_connected(_on_element_drafted):
		DraftManager.element_drafted.connect(_on_element_drafted)


## Disconnect from DraftManager signals (used in cleanup and tests).
func _disconnect_draft_signals() -> void:
	if DraftManager.draft_started.is_connected(_on_draft_started):
		DraftManager.draft_started.disconnect(_on_draft_started)
	if DraftManager.element_drafted.is_connected(_on_element_drafted):
		DraftManager.element_drafted.disconnect(_on_element_drafted)


func _on_draft_started(_starting_element: String) -> void:
	_refresh_draft_filter()


func _on_element_drafted(_element: String) -> void:
	_refresh_draft_filter()


## Update button and group header visibility based on current draft state.
func _refresh_draft_filter() -> void:
	_update_draft_indicator()

	for i: int in range(_available_towers.size()):
		if i < _tower_buttons.size():
			var tower: TowerData = _available_towers[i]
			_tower_buttons[i].visible = DraftManager.is_tower_available(tower)


func get_tower_data_by_index(index: int) -> TowerData:
	## Return the TowerData at the given 0-based index in the build menu order.
	## Only considers towers that are visible (not filtered out by draft mode).
	## Returns null if index is out of range.
	var visible_index: int = 0
	for i: int in range(_available_towers.size()):
		if i < _tower_buttons.size() and _tower_buttons[i].visible:
			if visible_index == index:
				return _available_towers[i]
			visible_index += 1
	return null


func _process(_delta: float) -> void:
	# Gray out buttons player can't afford
	for i: int in range(_available_towers.size()):
		if i < _tower_buttons.size():
			_tower_buttons[i].disabled = not EconomyManager.can_afford(_available_towers[i].cost)
