extends PanelContainer

## Shows selected tower stats with Upgrade, Sell, Fuse buttons and targeting mode dropdown.
## Displays tier, element, all combat stats, special ability, upgrade preview,
## sell value, and synergy info. Element-colored header and border styling.

signal fuse_requested(tower: Node)

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var tier_label: Label = $VBoxContainer/TierLabel
@onready var element_label: Label = $VBoxContainer/ElementLabel
@onready var separator_top: HSeparator = $VBoxContainer/SeparatorTop
@onready var damage_label: Label = $VBoxContainer/DamageLabel
@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var range_label: Label = $VBoxContainer/RangeLabel
@onready var special_label: Label = $VBoxContainer/SpecialLabel
@onready var synergy_label: Label = $VBoxContainer/SynergyLabel
@onready var separator_bottom: HSeparator = $VBoxContainer/SeparatorBottom
@onready var upgrade_cost_label: Label = $VBoxContainer/UpgradeCostLabel
@onready var sell_value_label: Label = $VBoxContainer/SellValueLabel
@onready var target_mode_dropdown: OptionButton = $VBoxContainer/TargetModeDropdown
@onready var button_row: HBoxContainer = $VBoxContainer/ButtonRow
@onready var upgrade_button: Button = $VBoxContainer/ButtonRow/UpgradeButton
@onready var sell_button: Button = $VBoxContainer/ButtonRow/SellButton
@onready var fuse_button: Button = $VBoxContainer/FuseButton

var _tower: Node = null

# Element colors matching BuildMenu for visual consistency
const ELEMENT_COLORS: Dictionary = {
	"fire": Color(0.9, 0.25, 0.15),
	"water": Color(0.2, 0.5, 0.95),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.8, 0.35),
	"lightning": Color(0.95, 0.85, 0.15),
	"ice": Color(0.3, 0.85, 0.9),
}

const ELEMENT_BG_COLORS: Dictionary = {
	"fire": Color(0.35, 0.12, 0.1, 0.92),
	"water": Color(0.1, 0.18, 0.35, 0.92),
	"earth": Color(0.25, 0.18, 0.1, 0.92),
	"wind": Color(0.12, 0.28, 0.14, 0.92),
	"lightning": Color(0.3, 0.28, 0.08, 0.92),
	"ice": Color(0.1, 0.25, 0.3, 0.92),
}

# Target mode labels matching Tower.TargetMode enum order
const TARGET_MODE_LABELS: PackedStringArray = ["First", "Last", "Strongest", "Weakest", "Closest"]


func _ready() -> void:
	UIManager.register_tower_info_panel(self)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	fuse_button.pressed.connect(_on_fuse_pressed)
	target_mode_dropdown.item_selected.connect(_on_target_mode_selected)
	TowerSystem.tower_upgraded.connect(_on_tower_upgraded)
	TowerSystem.tower_fused.connect(_on_tower_fused)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	# Populate target mode dropdown items once
	target_mode_dropdown.clear()
	for label_text: String in TARGET_MODE_LABELS:
		target_mode_dropdown.add_item(label_text)


func display_tower(tower: Node) -> void:
	_tower = tower
	# Sync dropdown to tower's current target mode
	if _tower:
		target_mode_dropdown.selected = _tower.target_mode
	_refresh()


func _refresh() -> void:
	if not _tower or not is_instance_valid(_tower):
		return
	var data: TowerData = _tower.tower_data
	var next: TowerData = data.upgrade_to

	# Tower name with element color
	name_label.text = data.tower_name
	var elem_color: Color = ELEMENT_COLORS.get(data.element, Color.WHITE)
	name_label.add_theme_color_override("font_color", elem_color)

	# Tier display
	tier_label.text = _get_tier_text(data)
	tier_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Element (show fusion elements for tier 2/3)
	if data.fusion_elements.size() > 1:
		var elems: PackedStringArray = PackedStringArray()
		for elem: String in data.fusion_elements:
			elems.append(elem.capitalize())
		element_label.text = "Elements: %s" % " + ".join(elems)
	else:
		element_label.text = "Element: %s" % data.element.capitalize()
	element_label.add_theme_color_override("font_color", elem_color.lightened(0.3))

	# Combat stats with upgrade preview arrows
	damage_label.text = _stat_text("Damage", data.damage, next.damage if next else -1)
	speed_label.text = _stat_text_f("Speed", data.attack_speed, next.attack_speed if next else -1.0, "/s")
	range_label.text = _stat_text("Range", data.range_cells, next.range_cells if next else -1, " cells")

	# Special ability description
	if data.special_description != "":
		special_label.text = data.special_description
		if next and next.special_description != "" and next.special_description != data.special_description:
			special_label.text += "\n  -> %s" % next.special_description
		special_label.visible = true
	else:
		special_label.visible = false

	# Synergy info
	_update_synergy_label(data)

	# Upgrade cost line
	_update_upgrade_cost_label(data)

	# Sell value line
	_update_sell_value_label(data)

	# Upgrade button
	_update_upgrade_button(data)

	# Sell button
	_update_sell_button()

	# Fuse button visibility and text
	_update_fuse_button(data)

	# Apply element-colored panel styling
	_apply_panel_style(data.element)


func _get_tier_text(data: TowerData) -> String:
	match data.tier:
		1:
			if data.upgrade_to == null:
				return "Superior"
			# Check if this tower's upgrade_to also has an upgrade_to (meaning this is base)
			if data.upgrade_to and data.upgrade_to.upgrade_to != null:
				return "Tier 1"
			return "Enhanced"
		2:
			return "Fusion"
		3:
			return "Legendary"
	return "Tier %d" % data.tier


func _stat_text(label: String, current: int, next_val: int, suffix: String = "") -> String:
	if next_val > 0 and next_val != current:
		return "%s: %d  ->  %d%s" % [label, current, next_val, suffix]
	return "%s: %d%s" % [label, current, suffix]


func _stat_text_f(label: String, current: float, next_val: float, suffix: String = "") -> String:
	if next_val > 0.0 and not is_equal_approx(next_val, current):
		return "%s: %.1f  ->  %.1f%s" % [label, current, next_val, suffix]
	return "%s: %.1f%s" % [label, current, suffix]


func _update_synergy_label(data: TowerData) -> void:
	if not _tower or not is_instance_valid(_tower):
		synergy_label.visible = false
		return
	var best_tier: int = ElementSynergy.get_best_synergy_tier(_tower)
	if best_tier <= 0:
		synergy_label.visible = false
		return
	# Show synergy tier with bonus info
	var bonus_mult: float = ElementSynergy.get_best_synergy_bonus(_tower)
	var bonus_pct: int = int((bonus_mult - 1.0) * 100.0)
	var elements: Array[String] = []
	if data.fusion_elements.size() > 0:
		elements = data.fusion_elements.duplicate()
	else:
		elements = [data.element]
	# Find which element gives the best synergy
	var best_elem: String = ""
	for elem: String in elements:
		if ElementSynergy.get_synergy_tier(elem) == best_tier:
			best_elem = elem
			break
	var count: int = ElementSynergy.get_element_count(best_elem)
	synergy_label.text = "Synergy: %s x%d (+%d%% dmg)" % [best_elem.capitalize(), count, bonus_pct]
	var synergy_color: Color = ELEMENT_COLORS.get(best_elem, Color.WHITE).lightened(0.4)
	synergy_label.add_theme_color_override("font_color", synergy_color)
	synergy_label.visible = true


func _update_upgrade_cost_label(data: TowerData) -> void:
	if data.upgrade_to == null:
		upgrade_cost_label.text = "Upgrade: Max"
		upgrade_cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		var cost: int = data.upgrade_to.cost - data.cost
		if EconomyManager.can_afford(cost):
			upgrade_cost_label.text = "Upgrade: %dg" % cost
			upgrade_cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			upgrade_cost_label.text = "Upgrade: %dg (need %dg)" % [cost, cost - EconomyManager.gold]
			upgrade_cost_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))


func _update_sell_value_label(data: TowerData) -> void:
	var refund_pct: float = 0.75 if GameManager.game_state == GameManager.GameState.BUILD_PHASE else 0.50
	var refund: int = int(data.cost * refund_pct)
	var phase_text: String = "75%" if GameManager.game_state == GameManager.GameState.BUILD_PHASE else "50%"
	sell_value_label.text = "Sell value: %dg (%s)" % [refund, phase_text]
	sell_value_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))


func _update_upgrade_button(data: TowerData) -> void:
	if data.upgrade_to == null:
		upgrade_button.text = "Max"
		upgrade_button.disabled = true
	else:
		var cost: int = data.upgrade_to.cost - data.cost
		upgrade_button.text = "Upgrade"
		upgrade_button.disabled = not EconomyManager.can_afford(cost)


func _update_sell_button() -> void:
	sell_button.text = "Sell"


func _update_fuse_button(data: TowerData) -> void:
	if not _tower or not is_instance_valid(_tower):
		fuse_button.visible = false
		return
	# Fusion eligible: Superior (tier 1, no upgrade_to) or Tier 2 (for legendary)
	var can_dual: bool = data.tier == 1 and data.upgrade_to == null
	var can_legendary: bool = data.tier == 2
	# Also check: tower 1 Superior can be the "superior" input for a legendary with an existing tier 2
	var has_legendary_as_superior: bool = false
	if can_dual:
		var leg_partners: Array[Node] = FusionRegistry.get_legendary_partners(_tower)
		has_legendary_as_superior = leg_partners.size() > 0

	if can_dual:
		var partners: Array[Node] = FusionRegistry.get_fusion_partners(_tower)
		if partners.size() > 0 or has_legendary_as_superior:
			fuse_button.visible = true
			fuse_button.text = "Fuse..."
			fuse_button.disabled = false
		else:
			fuse_button.visible = false
	elif can_legendary:
		var partners: Array[Node] = FusionRegistry.get_legendary_partners(_tower)
		if partners.size() > 0:
			fuse_button.visible = true
			fuse_button.text = "Legendary Fuse..."
			fuse_button.disabled = false
		else:
			fuse_button.visible = false
	else:
		fuse_button.visible = false


func _apply_panel_style(element: String) -> void:
	var bg_color: Color = ELEMENT_BG_COLORS.get(element, Color(0.15, 0.15, 0.18, 0.92))
	var border_color: Color = ELEMENT_COLORS.get(element, Color(0.4, 0.4, 0.4))

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)


func _process(_delta: float) -> void:
	if not visible or not _tower or not is_instance_valid(_tower):
		return
	# Keep upgrade button affordability up to date
	var data: TowerData = _tower.tower_data
	if data.upgrade_to != null:
		var cost: int = data.upgrade_to.cost - data.cost
		upgrade_button.disabled = not EconomyManager.can_afford(cost)


func _on_upgrade_pressed() -> void:
	if _tower and is_instance_valid(_tower):
		TowerSystem.upgrade_tower(_tower)


func _on_sell_pressed() -> void:
	if _tower and is_instance_valid(_tower):
		TowerSystem.sell_tower(_tower)
		UIManager.deselect_tower()


func _on_fuse_pressed() -> void:
	if _tower and is_instance_valid(_tower):
		fuse_requested.emit(_tower)


func _on_target_mode_selected(index: int) -> void:
	if _tower and is_instance_valid(_tower):
		# TargetMode enum values match dropdown indices: 0=FIRST, 1=LAST, 2=STRONGEST, 3=WEAKEST, 4=CLOSEST
		_tower.target_mode = index


func _on_tower_upgraded(tower: Node) -> void:
	if tower == _tower:
		_refresh()


func _on_tower_fused(tower: Node) -> void:
	if tower == _tower:
		_refresh()


func _on_gold_changed(_new_amount: int) -> void:
	if visible and _tower and is_instance_valid(_tower):
		_update_upgrade_cost_label(_tower.tower_data)
		_update_upgrade_button(_tower.tower_data)
		_update_fuse_button(_tower.tower_data)


func _on_phase_changed(_new_phase: GameManager.GameState) -> void:
	if visible and _tower and is_instance_valid(_tower):
		_update_sell_value_label(_tower.tower_data)
