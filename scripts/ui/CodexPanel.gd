extends PanelContainer

## In-game Codex/Encyclopedia. Tabbed overlay with Fusions, Towers, Elements, Enemies.
## Opens via HUD button or C key. Self-registers with UIManager.

## Emitted when the Codex panel is closed, so callers (e.g. PauseMenu) can react.
signal closed

@onready var content_container: VBoxContainer = $VBoxContainer/ScrollContainer/ContentContainer
@onready var tab_buttons: Array[Button] = [
	$VBoxContainer/TabBar/TowersTab,
	$VBoxContainer/TabBar/ElementsTab,
	$VBoxContainer/TabBar/EnemiesTab,
	$VBoxContainer/TabBar/ModesTab,
]
@onready var close_button: Button = $VBoxContainer/HeaderBar/CloseButton

const TABS: Array[String] = ["Towers", "Elements", "Enemies", "Modes"]
var _current_tab: int = 0
# Tracks whether the scene tree was already paused when we opened,
# so we only unpause on close if we were the ones who paused it.
var _was_paused_before_open: bool = false

# Element colors matching the game's visual style
const ELEMENT_COLORS: Dictionary = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.3, 0.5, 1.0),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.6, 1.0, 0.6),
	"lightning": Color(1.0, 1.0, 0.3),
	"ice": Color(0.7, 0.9, 1.0),
}

# Trait tag colors (shared with WavePreviewPanel)
const TRAIT_COLORS: Dictionary = {
	"Boss": Color(1.0, 0.3, 0.2),
	"Flying": Color(0.5, 0.8, 1.0),
	"Stealth": Color(0.6, 0.4, 0.8),
	"Healer": Color(0.3, 0.9, 0.4),
	"Splits": Color(0.9, 0.7, 0.3),
	"Swarm": Color(0.9, 0.6, 0.2),
	"Armored": Color(0.7, 0.6, 0.5),
	"Elemental": Color(0.8, 0.5, 0.9),
}

# Tower resource directories
const TOWER_BASE_DIR: String = "res://resources/towers/"
const TOWER_FUSION_DIR: String = "res://resources/towers/fusions/"
const TOWER_LEGENDARY_DIR: String = "res://resources/towers/legendaries/"
const ENEMY_DIR: String = "res://resources/enemies/"


func _ready() -> void:
	# Must process while the tree is paused (opened from HUD or from PauseMenu).
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	UIManager.register_codex(self)
	visible = false
	_apply_panel_style()
	close_button.pressed.connect(_on_close_pressed)
	for i: int in tab_buttons.size():
		tab_buttons[i].pressed.connect(_on_tab_pressed.bind(i))
	_update_tab_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		_close()
	else:
		# Record whether the game was already paused (e.g. opened from PauseMenu)
		# so _close() knows whether to restore the running state.
		_was_paused_before_open = GameManager.is_paused()
		GameManager.pause()
		visible = true
		_build_tab_content(_current_tab)


func _close() -> void:
	visible = false
	# Only unpause if we paused the tree ourselves when opening.
	# If the game was already paused (e.g. opened from PauseMenu), leave it paused.
	if not _was_paused_before_open:
		GameManager.unpause()
	closed.emit()


func _on_close_pressed() -> void:
	_close()


func _on_tab_pressed(tab_index: int) -> void:
	if tab_index == _current_tab:
		return
	_current_tab = tab_index
	_update_tab_visuals()
	_build_tab_content(tab_index)


func _update_tab_visuals() -> void:
	for i: int in tab_buttons.size():
		if i == _current_tab:
			tab_buttons[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.25, 0.25, 0.35, 1.0)
			style.set_border_width_all(1)
			style.border_color = Color(0.5, 0.5, 0.6)
			style.set_corner_radius_all(3)
			style.set_content_margin_all(6)
			tab_buttons[i].add_theme_stylebox_override("normal", style)
		else:
			tab_buttons[i].add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
			style.set_corner_radius_all(3)
			style.set_content_margin_all(6)
			tab_buttons[i].add_theme_stylebox_override("normal", style)


func _build_tab_content(tab_index: int) -> void:
	_clear_content()
	match tab_index:
		0:
			_build_towers_tab()
		1:
			_build_elements_tab()
		2:
			_build_enemies_tab()
		3:
			_build_modes_tab()


func _clear_content() -> void:
	for child: Node in content_container.get_children():
		child.queue_free()


# --- Towers Tab ---

func _build_towers_tab() -> void:
	# Base towers (6)
	_add_section_header("Base Towers")
	var base_files: PackedStringArray = [
		"flame_spire", "tidal_obelisk", "stone_bastion",
		"gale_tower", "thunder_pylon", "frost_sentinel",
	]
	for f: String in base_files:
		var data: TowerData = load(TOWER_BASE_DIR + f + ".tres")
		if data:
			content_container.add_child(_create_tower_entry(data))

	_add_spacer(8)

	# Enhanced towers (6)
	_add_section_header("Enhanced Towers (Tier 1 Upgrade)")
	for f: String in base_files:
		var data: TowerData = load(TOWER_BASE_DIR + f + "_enhanced.tres")
		if data:
			content_container.add_child(_create_tower_entry(data))

	_add_spacer(8)

	# Superior towers (6)
	_add_section_header("Superior Towers (Tier 1 Max)")
	for f: String in base_files:
		var data: TowerData = load(TOWER_BASE_DIR + f + "_superior.tres")
		if data:
			content_container.add_child(_create_tower_entry(data))

	_add_spacer(8)

	# Fusion towers (15)
	_add_section_header("Fusion Towers (Tier 2)")
	var dual_fusions: Dictionary = FusionRegistry.get_all_dual_fusions()
	var dual_keys: Array = dual_fusions.keys()
	dual_keys.sort()
	for key: String in dual_keys:
		var data: TowerData = load(dual_fusions[key])
		if data:
			content_container.add_child(_create_tower_entry(data))

	_add_spacer(8)

	# Legendary towers (6)
	_add_section_header("Legendary Towers (Tier 3)")
	var legendary_fusions: Dictionary = FusionRegistry.get_all_legendary_fusions()
	var legendary_keys: Array = legendary_fusions.keys()
	legendary_keys.sort()
	for key: String in legendary_keys:
		var data: TowerData = load(legendary_fusions[key])
		if data:
			content_container.add_child(_create_tower_entry(data))


func _create_tower_entry(data: TowerData) -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 1)

	# Header row: element dot + name + tier badge
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)

	# Element dot(s)
	if data.fusion_elements.size() > 0:
		for e: String in data.fusion_elements:
			header.add_child(_create_element_dot(e))
	else:
		header.add_child(_create_element_dot(data.element))

	var name_label := Label.new()
	var tier_text: String = ""
	match data.tier:
		2:
			tier_text = " [Fusion]"
		3:
			tier_text = " [Legendary]"
	name_label.text = data.tower_name + tier_text
	name_label.add_theme_font_size_override("font_size", 13)
	var name_color: Color = Color(0.95, 0.95, 0.95)
	if data.tier == 3:
		name_color = Color(1.0, 0.8, 0.4)
	elif data.tier == 2:
		name_color = Color(0.95, 0.9, 0.7)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	wrapper.add_child(header)

	# Stats row
	var stats := Label.new()
	var speed_text: String = "%.1f/s" % data.attack_speed if data.attack_speed > 0.0 else "Aura"
	stats.text = "    Dmg: %d  |  Speed: %s  |  Range: %d  |  Cost: %dg" % [
		data.damage, speed_text, data.range_cells, data.cost
	]
	stats.add_theme_font_size_override("font_size", 11)
	stats.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	wrapper.add_child(stats)

	# Special description
	if data.special_description != "":
		var desc := Label.new()
		desc.text = "    Special: %s" % data.special_description
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.5, 0.7, 0.55))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wrapper.add_child(desc)

	# Small separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	wrapper.add_child(sep)

	return wrapper


# --- Elements Tab ---

func _build_elements_tab() -> void:
	_add_section_header("Elemental Damage Matrix")
	_add_section_subtitle("Rows = Attacker, Columns = Defender")

	# Build the 6x6 grid as a GridContainer
	var grid := GridContainer.new()
	grid.columns = 7  # 1 header column + 6 element columns
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)

	# Top-left empty corner
	var corner := Label.new()
	corner.text = ""
	corner.custom_minimum_size = Vector2(70, 24)
	grid.add_child(corner)

	# Column headers (defender elements)
	for element: String in ElementMatrix.ELEMENTS:
		var header := Label.new()
		header.text = element.substr(0, 3).to_upper()
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", _get_element_color(element))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.custom_minimum_size = Vector2(50, 24)
		grid.add_child(header)

	# Rows (attacker elements)
	for attacker: String in ElementMatrix.ELEMENTS:
		# Row header
		var row_header := Label.new()
		row_header.text = attacker.capitalize()
		row_header.add_theme_font_size_override("font_size", 11)
		row_header.add_theme_color_override("font_color", _get_element_color(attacker))
		row_header.custom_minimum_size = Vector2(70, 22)
		grid.add_child(row_header)

		# Multiplier cells
		for defender: String in ElementMatrix.ELEMENTS:
			var mult: float = ElementMatrix.get_multiplier(attacker, defender)
			var cell := Label.new()
			cell.text = "%sx" % _format_mult(mult)
			cell.add_theme_font_size_override("font_size", 11)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.custom_minimum_size = Vector2(50, 22)

			# Color coding: green for strong, red for weak, gray for neutral
			if mult > 1.0:
				var intensity: float = (mult - 1.0) / 0.5  # 1.25 -> 0.5, 1.5 -> 1.0
				cell.add_theme_color_override("font_color", Color(0.4, 0.5 + 0.5 * intensity, 0.4))
			elif mult < 1.0:
				var intensity: float = (1.0 - mult) / 0.5  # 0.75 -> 0.5, 0.5 -> 1.0
				cell.add_theme_color_override("font_color", Color(0.5 + 0.5 * intensity, 0.4, 0.4))
			else:
				cell.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			grid.add_child(cell)

	content_container.add_child(grid)

	_add_spacer(16)

	# Counter relationships
	_add_section_header("Counter Relationships")
	_add_section_subtitle("Each element's primary counter (deals 1.5x damage)")

	for element: String in ElementMatrix.ELEMENTS:
		var counter: String = ElementMatrix.get_counter(element)
		if counter == "":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		row.add_child(_create_element_dot(element))

		var arrow := Label.new()
		arrow.text = "%s  is countered by" % element.capitalize()
		arrow.add_theme_font_size_override("font_size", 12)
		arrow.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		row.add_child(arrow)

		row.add_child(_create_element_dot(counter))

		var counter_label := Label.new()
		counter_label.text = counter.capitalize()
		counter_label.add_theme_font_size_override("font_size", 12)
		counter_label.add_theme_color_override("font_color", _get_element_color(counter))
		row.add_child(counter_label)

		content_container.add_child(row)

	_add_spacer(16)

	# Element color legend
	_add_section_header("Element Colors")
	var legend_row := HBoxContainer.new()
	legend_row.add_theme_constant_override("separation", 16)
	for element: String in ElementMatrix.ELEMENTS:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		item.add_child(_create_element_dot(element))
		var lbl := Label.new()
		lbl.text = element.capitalize()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", _get_element_color(element))
		item.add_child(lbl)
		legend_row.add_child(item)
	content_container.add_child(legend_row)


# --- Enemies Tab ---

func _build_enemies_tab() -> void:
	var enemy_files: PackedStringArray = [
		"normal", "fast", "armored", "swarm", "flying",
		"healer", "split", "stealth", "elemental",
		"boss_ember_titan", "boss_glacial_wyrm", "boss_chaos_elemental",
	]

	_add_section_header("Regular Enemies")

	for filename: String in enemy_files:
		var data: EnemyData = load(ENEMY_DIR + filename + ".tres")
		if data == null:
			continue

		# Insert boss section header before first boss
		if data.is_boss and filename == "boss_ember_titan":
			_add_spacer(8)
			_add_section_header("Bosses")

		content_container.add_child(_create_enemy_entry(data, filename))


func _create_enemy_entry(data: EnemyData, filename: String) -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 1)

	# Header row: name + traits
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = data.enemy_name
	name_label.add_theme_font_size_override("font_size", 13)
	if data.is_boss:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	else:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	header.add_child(name_label)

	# Trait tags
	var traits: PackedStringArray = _get_enemy_traits(data, filename)
	if traits.size() > 0:
		for t: String in traits:
			var tag := Label.new()
			tag.text = "[%s]" % t
			tag.add_theme_font_size_override("font_size", 10)
			tag.add_theme_color_override("font_color", TRAIT_COLORS.get(t, Color(0.7, 0.7, 0.7)))
			header.add_child(tag)

	wrapper.add_child(header)

	# Stats row
	var stats := Label.new()
	stats.text = "    HP: %d  |  Speed: %.1fx  |  Gold: %d" % [
		data.base_health, data.speed_multiplier, data.gold_reward
	]
	stats.add_theme_font_size_override("font_size", 11)
	stats.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	wrapper.add_child(stats)

	# Special/description line
	if data.special != "":
		var desc := Label.new()
		desc.text = "    %s" % data.special
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.65, 0.55, 0.55))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wrapper.add_child(desc)

	# Element info if applicable
	if data.element != "" and data.element != "none":
		var elem_label := Label.new()
		elem_label.text = "    Element: %s" % data.element.capitalize()
		elem_label.add_theme_font_size_override("font_size", 11)
		elem_label.add_theme_color_override("font_color", _get_element_color(data.element))
		wrapper.add_child(elem_label)

	if data.immune_element != "":
		var immune_label := Label.new()
		immune_label.text = "    Immune to: %s" % data.immune_element.capitalize()
		immune_label.add_theme_font_size_override("font_size", 11)
		immune_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		wrapper.add_child(immune_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	wrapper.add_child(sep)

	return wrapper


func _get_enemy_traits(data: EnemyData, filename: String) -> PackedStringArray:
	var traits: PackedStringArray = PackedStringArray()
	if data.is_boss:
		traits.append("Boss")
	if data.is_flying:
		traits.append("Flying")
	if data.stealth:
		traits.append("Stealth")
	if data.heal_per_second > 0.0:
		traits.append("Healer")
	if data.split_on_death:
		traits.append("Splits")
	if data.spawn_count > 1:
		traits.append("Swarm")
	if data.physical_resist > 0.0:
		traits.append("Armored")
	if filename == "elemental":
		traits.append("Elemental")
	return traits


# --- Modes Tab ---

func _build_modes_tab() -> void:
	_add_section_header("Classic Mode")
	_add_mode_bullet("30 waves of increasing difficulty")
	_add_mode_bullet("Boss waves at 10, 20, 30")
	_add_mode_bullet("Income phases every 5 waves (interest on banked gold)")
	_add_mode_bullet("Start with 20 lives, earn gold from kills and wave bonuses")
	_add_mode_bullet("Victory: survive all 30 waves and defeat the final boss")

	_add_spacer(12)

	_add_section_header("Draft Mode")
	_add_mode_bullet("Same 30-wave structure as Classic")
	_add_mode_bullet("Before the game starts, draft towers from randomized picks")
	_add_mode_bullet("Only drafted tower types can be built during the game")
	_add_mode_bullet("Both elements must be drafted for fusion to work")
	_add_mode_bullet("Strategy: balance element coverage vs. powerful fusion paths")

	_add_spacer(12)

	_add_section_header("Endless Mode")
	_add_mode_bullet("Waves continue beyond 30 with scaling difficulty")
	_add_mode_bullet("Enemy variety and count increase each wave")
	_add_mode_bullet("Boss every 10 waves (cycling through all 3 bosses)")
	_add_mode_bullet("No victory condition — survive as long as possible")
	_add_mode_bullet("Leaderboard: waves survived and total gold earned")


func _add_mode_bullet(text: String) -> void:
	var label := Label.new()
	label.text = "  •  %s" % text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(label)


# --- Helper methods ---

func _create_element_dot(element: String) -> ColorRect:
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.color = _get_element_color(element)
	# Round via stylebox
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot


func _get_element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, Color(0.5, 0.5, 0.5))


func _format_mult(value: float) -> String:
	if value == int(value):
		return "%d.0" % int(value)
	# Show 2 decimal places but trim trailing zeros
	return "%.2f" % value


func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	content_container.add_child(label)

	var sep := HSeparator.new()
	content_container.add_child(sep)


func _add_section_subtitle(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	content_container.add_child(label)
	_add_spacer(4)


func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	content_container.add_child(spacer)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.35, 0.35, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
