extends PanelContainer

## Displays upcoming wave enemy composition during build phase.
## Shows enemy type icons, names, counts, and notable traits (boss, flying, stealth, etc.).

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var enemy_list: VBoxContainer = $VBoxContainer/EnemyList
@onready var boss_banner: Label = $VBoxContainer/BossBanner
@onready var combat_label: Label = $VBoxContainer/CombatLabel

const ENEMY_SPRITE_DIR: String = "res://assets/sprites/enemies/"
const ICON_SIZE: int = 24

# Trait tag colors for visual distinction
const TRAIT_COLORS: Dictionary = {
	"BOSS": Color(1.0, 0.3, 0.2),
	"Flying": Color(0.5, 0.8, 1.0),
	"Stealth": Color(0.6, 0.4, 0.8),
	"Healer": Color(0.3, 0.9, 0.4),
	"Splits": Color(0.9, 0.7, 0.3),
	"Swarm": Color(0.9, 0.6, 0.2),
	"Armored": Color(0.7, 0.6, 0.5),
	"Elemental": Color(0.8, 0.5, 0.9),
}

# Element colors for boss element indicators
const ELEMENT_COLORS: Dictionary = {
	"fire": Color(0.9, 0.25, 0.15),
	"water": Color(0.2, 0.5, 0.95),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.8, 0.35),
	"lightning": Color(0.95, 0.85, 0.15),
	"ice": Color(0.3, 0.85, 0.9),
	"none": Color(0.7, 0.7, 0.7),
}


func _ready() -> void:
	UIManager.register_wave_preview(self)
	GameManager.phase_changed.connect(_on_phase_changed)
	boss_banner.visible = false
	combat_label.visible = false
	# Apply default dark panel style
	_apply_panel_style()


func display_wave(wave_number: int) -> void:
	## Populate the panel with the upcoming wave's enemy composition.
	var wave_data: Dictionary = EnemySystem.get_wave_config(wave_number)
	if wave_data.is_empty():
		title_label.text = "Wave %d" % wave_number
		_clear_enemy_list()
		var fallback := Label.new()
		fallback.text = "  Unknown composition"
		fallback.add_theme_font_size_override("font_size", 11)
		fallback.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		enemy_list.add_child(fallback)
		boss_banner.visible = false
		combat_label.visible = false
		visible = true
		return

	var is_boss: bool = wave_data.get("is_boss_wave", false)
	var is_income: bool = wave_data.get("is_income_wave", false)

	# Title with wave number and optional income indicator
	var title_text: String = "Wave %d" % wave_number
	if is_income:
		title_text += "  [Income]"
	title_label.text = title_text

	# Boss banner
	if is_boss:
		boss_banner.visible = true
		# Find the boss name from the enemies list
		var boss_name: String = _find_boss_name(wave_data)
		boss_banner.text = "BOSS: %s" % boss_name if boss_name != "" else "BOSS WAVE"
	else:
		boss_banner.visible = false

	# Populate enemy rows
	_clear_enemy_list()
	var enemy_groups: Array = wave_data.get("enemies", [])
	for group: Dictionary in enemy_groups:
		var enemy_type: String = group.get("type", "")
		var count: int = int(group.get("count", 0))
		var row: HBoxContainer = _create_enemy_row(enemy_type, count)
		enemy_list.add_child(row)

	combat_label.visible = false
	visible = true


func show_combat_message() -> void:
	## Show a minimal "Wave in progress..." message during combat.
	combat_label.visible = true
	combat_label.text = "Wave in progress..."
	boss_banner.visible = false
	_clear_enemy_list()


func _on_phase_changed(new_phase: GameManager.GameState) -> void:
	match new_phase:
		GameManager.GameState.BUILD_PHASE:
			# current_wave was already incremented in _transition_to(BUILD_PHASE)
			display_wave(GameManager.current_wave)
		GameManager.GameState.COMBAT_PHASE:
			show_combat_message()
		GameManager.GameState.GAME_OVER:
			visible = false


func _clear_enemy_list() -> void:
	for child: Node in enemy_list.get_children():
		child.queue_free()


func _find_boss_name(wave_data: Dictionary) -> String:
	## Scan enemy groups for a boss type and return its display name.
	var enemy_groups: Array = wave_data.get("enemies", [])
	for group: Dictionary in enemy_groups:
		var enemy_type: String = group.get("type", "")
		if enemy_type.begins_with("boss_"):
			var template: EnemyData = EnemySystem.get_enemy_template(enemy_type)
			if template:
				return template.enemy_name
	return ""


func _create_enemy_row(enemy_type: String, count: int) -> HBoxContainer:
	## Build a single row: [icon] Name x Count [trait tags]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var template: EnemyData = EnemySystem.get_enemy_template(enemy_type)

	# Enemy icon (sprite thumbnail)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var sprite_path: String = ENEMY_SPRITE_DIR + enemy_type + ".png"
	var tex: Texture2D = load(sprite_path)
	if tex:
		icon.texture = tex
	row.add_child(icon)

	# Display name and count
	var display_name: String = enemy_type.capitalize()
	var actual_count: int = count
	if template:
		display_name = template.enemy_name
		# Swarm enemies actually spawn count * spawn_count units
		actual_count = count * template.spawn_count

	var name_label := Label.new()
	name_label.text = "%s x%d" % [display_name, actual_count]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Trait tags
	var traits: PackedStringArray = _get_enemy_traits(template, enemy_type)
	if traits.size() > 0:
		var tag_label := Label.new()
		tag_label.text = " ".join(traits)
		tag_label.add_theme_font_size_override("font_size", 10)
		# Color based on first (most important) trait
		var tag_color: Color = TRAIT_COLORS.get(traits[0], Color(0.7, 0.7, 0.7))
		tag_label.add_theme_color_override("font_color", tag_color)
		row.add_child(tag_label)

	return row


func _get_enemy_traits(template: EnemyData, enemy_type: String) -> PackedStringArray:
	## Determine notable trait tags for display.
	var traits: PackedStringArray = PackedStringArray()
	if template == null:
		return traits

	if template.is_boss:
		traits.append("BOSS")
	if template.is_flying:
		traits.append("Flying")
	if template.stealth:
		traits.append("Stealth")
	if template.heal_per_second > 0.0:
		traits.append("Healer")
	if template.split_on_death:
		traits.append("Splits")
	if template.spawn_count > 1:
		traits.append("Swarm")
	if template.physical_resist > 0.0:
		traits.append("Armored")
	if enemy_type == "elemental":
		traits.append("Elemental")
	if template.immune_element != "":
		traits.append("Immune:%s" % template.immune_element.capitalize())

	return traits


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.92)
	style.border_color = Color(0.35, 0.35, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
