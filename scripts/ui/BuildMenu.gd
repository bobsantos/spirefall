extends Control

## Bottom panel: scrollable row of tower build buttons grouped by element.
## Each button shows tower name, cost, element color, sprite thumbnail, and
## provides a tooltip with stats on hover.

signal tower_build_selected(tower_data: TowerData)

@onready var button_container: HBoxContainer = $ScrollContainer/HBoxContainer

var _tower_buttons: Array[Button] = []
var _available_towers: Array[TowerData] = []

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
	_create_buttons()


func _load_available_towers() -> void:
	# Load all tier-1 base towers (no fusions, no enhanced/superior)
	var tower_dir := "res://resources/towers/"
	var dir := DirAccess.open(tower_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			# Skip enhanced/superior upgrades -- only show base towers
			var lower_name := file_name.to_lower()
			if lower_name.contains("enhanced") or lower_name.contains("superior"):
				file_name = dir.get_next()
				continue
			var tower: TowerData = load(tower_dir + file_name)
			if tower and tower.tier == 1:
				_available_towers.append(tower)
		file_name = dir.get_next()
	# Sort by canonical element order for consistent button layout
	_available_towers.sort_custom(func(a: TowerData, b: TowerData) -> bool:
		return ELEMENT_ORDER.find(a.element) < ELEMENT_ORDER.find(b.element)
	)


func _create_buttons() -> void:
	var last_element: String = ""

	for tower: TowerData in _available_towers:
		# Add a colored separator + element label between element groups
		if tower.element != last_element:
			if last_element != "":
				_add_separator()
			_add_element_header(tower.element)
			last_element = tower.element

		var btn := _create_tower_button(tower)
		button_container.add_child(btn)
		_tower_buttons.append(btn)


func _add_element_header(element: String) -> void:
	var header := VBoxContainer.new()
	header.custom_minimum_size = Vector2(14, 0)
	header.alignment = BoxContainer.ALIGNMENT_CENTER

	# Small colored circle as element icon
	var icon := _create_element_icon(element, 10)
	header.add_child(icon)

	# Element initial letter label
	var label := Label.new()
	label.text = element.substr(0, 1).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	var element_color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	label.add_theme_color_override("font_color", element_color)
	header.add_child(label)

	button_container.add_child(header)


func _add_separator() -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(4, 0)
	button_container.add_child(sep)


func _create_tower_button(tower: TowerData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 64)
	btn.clip_text = true
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
	UIManager.request_build(tower_data)
	tower_build_selected.emit(tower_data)


func _process(_delta: float) -> void:
	# Gray out buttons player can't afford
	for i: int in range(_available_towers.size()):
		if i < _tower_buttons.size():
			_tower_buttons[i].disabled = not EconomyManager.can_afford(_available_towers[i].cost)
