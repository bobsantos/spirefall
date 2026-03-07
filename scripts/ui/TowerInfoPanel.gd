extends PanelContainer

## Action-only panel for selected tower: Upgrade, Sell, Fuse, Ascend buttons
## and targeting mode dropdown. Stats belong in the Codex.

signal fuse_requested(tower: Node)

@onready var name_label: Label = $VBoxContainer/HeaderRow/NameLabel
@onready var close_button: Button = $VBoxContainer/HeaderRow/CloseButton
@onready var target_mode_dropdown: OptionButton = $VBoxContainer/TargetModeDropdown
@onready var button_row: HBoxContainer = $VBoxContainer/ButtonRow
@onready var upgrade_button: Button = $VBoxContainer/ButtonRow/UpgradeButton
@onready var sell_button: Button = $VBoxContainer/ButtonRow/SellButton
@onready var ascend_button: Button = $VBoxContainer/AscendButton
@onready var fuse_button: Button = $VBoxContainer/FuseButton

var _tower: Node = null
var _last_screen_pos: Vector2 = Vector2.ZERO
var _mobile_mode: bool = false

const PANEL_MARGIN: float = 8.0   # Minimum distance from screen edge
const TOWER_OFFSET: float = 40.0  # Offset from tower to avoid overlap

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
	ascend_button.pressed.connect(_on_ascend_pressed)
	fuse_button.pressed.connect(_on_fuse_pressed)
	close_button.pressed.connect(_on_close_pressed)
	target_mode_dropdown.item_selected.connect(_on_target_mode_selected)
	TowerSystem.tower_upgraded.connect(_on_tower_upgraded)
	TowerSystem.tower_ascended.connect(_on_tower_ascended)
	TowerSystem.tower_fused.connect(_on_tower_fused)
	TowerSystem.fusion_failed.connect(_on_fusion_failed)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	# Populate target mode dropdown items once
	target_mode_dropdown.clear()
	for label_text: String in TARGET_MODE_LABELS:
		target_mode_dropdown.add_item(label_text)
	_style_close_button()
	_mobile_mode = UIManager.is_mobile()
	if _mobile_mode:
		_apply_mobile_sizing()


func _apply_mobile_sizing() -> void:
	var min_h: float = UIManager.MOBILE_ACTION_BUTTON_MIN_HEIGHT
	upgrade_button.custom_minimum_size.y = min_h
	sell_button.custom_minimum_size.y = min_h
	ascend_button.custom_minimum_size.y = min_h
	fuse_button.custom_minimum_size.y = min_h
	target_mode_dropdown.custom_minimum_size.y = min_h
	close_button.custom_minimum_size = UIManager.MOBILE_BUTTON_MIN
	# Bump name label font size to mobile minimum
	var body_size: int = UIManager.MOBILE_FONT_SIZE_BODY
	name_label.add_theme_font_size_override("font_size", body_size)
	# Widen panel for larger text
	custom_minimum_size.x = maxf(custom_minimum_size.x, 300.0)


func _style_close_button() -> void:
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(28, 28)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.28, 0.9)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)
	close_button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.35, 0.35, 0.38, 0.95)
	close_button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	close_button.add_theme_stylebox_override("pressed", pressed_style)


func _on_close_pressed() -> void:
	UIManager.deselect_tower()


func display_tower(tower: Node) -> void:
	_tower = tower
	# Sync dropdown to tower's current target mode
	if _tower:
		target_mode_dropdown.selected = _tower.target_mode
	# On mobile, dismiss build menu
	if _mobile_mode:
		if UIManager.build_menu and UIManager.build_menu.has_method("slide_out"):
			UIManager.build_menu.slide_out()
	visible = true
	_refresh()
	_reposition()


func _refresh() -> void:
	if not _tower or not is_instance_valid(_tower):
		return
	var data: TowerData = _tower.tower_data

	# Tower name with element color
	name_label.text = data.tower_name
	var elem_color: Color = ELEMENT_COLORS.get(data.element, Color.WHITE)
	name_label.add_theme_color_override("font_color", elem_color)

	# Upgrade button with cost in text
	_update_upgrade_button(data)

	# Sell button with refund in text
	_update_sell_button(data)

	# Ascend button visibility and text
	_update_ascend_button(data)

	# Fuse button visibility and text
	_update_fuse_button(data)

	# Apply element-colored panel styling
	_apply_panel_style(data.element)


func _update_upgrade_button(data: TowerData) -> void:
	if data.upgrade_to == null:
		upgrade_button.text = "Max"
		upgrade_button.disabled = true
	else:
		var cost: int = data.upgrade_to.cost - data.cost
		upgrade_button.text = "Upgrade (%dg)" % cost
		upgrade_button.disabled = not EconomyManager.can_afford(cost)


func _update_sell_button(data: TowerData) -> void:
	var refund_pct: float = 0.75 if GameManager.game_state == GameManager.GameState.BUILD_PHASE else 0.50
	var refund: int = int(data.cost * refund_pct)
	sell_button.text = "Sell (%dg)" % refund


func _update_fuse_button(data: TowerData) -> void:
	if not _tower or not is_instance_valid(_tower):
		fuse_button.visible = false
		return
	# Fusion eligible: Superior (tier 1, no upgrade_to, not Ascended) or Tier 2 (for legendary)
	var can_dual: bool = data.tier == 1 and data.upgrade_to == null and not data.tower_name.ends_with(" Ascended")
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


func _update_ascend_button(data: TowerData) -> void:
	if not ascend_button:
		return
	if not _tower or not is_instance_valid(_tower):
		ascend_button.visible = false
		return
	var can: bool = TowerSystem.can_ascend(_tower)
	var is_superior: bool = TowerSystem._is_superior(_tower) and not TowerSystem._is_ascended(_tower)
	var has_path: bool = data.element in TowerSystem.ASCENDED_PATHS
	if is_superior and has_path:
		ascend_button.visible = true
		var cost: int = TowerSystem.ASCEND_COST
		ascend_button.text = "Ascend (%dg)" % cost
		ascend_button.disabled = not can
	else:
		ascend_button.visible = false


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


func _get_tower_screen_pos() -> Vector2:
	if not _tower or not is_instance_valid(_tower):
		return Vector2.ZERO
	return _tower.get_global_transform_with_canvas().origin


func _reposition() -> void:
	if not _tower or not is_instance_valid(_tower):
		return
	if _mobile_mode:
		_reposition_mobile()
		return
	var screen_pos: Vector2 = _get_tower_screen_pos()
	_reposition_at(screen_pos)


func _reposition_mobile() -> void:
	var viewport_size: Vector2 = Vector2(1280, 960)
	if get_viewport():
		var vp_rect: Rect2 = get_viewport().get_visible_rect()
		if vp_rect.size.x > 0 and vp_rect.size.y > 0:
			viewport_size = vp_rect.size
	# Span full viewport width minus margins
	var full_width: float = viewport_size.x - 2.0 * PANEL_MARGIN
	custom_minimum_size.x = full_width
	size.x = full_width
	var panel_size: Vector2 = size
	# Bottom-dock at left margin
	var x: float = PANEL_MARGIN
	var y: float = viewport_size.y - panel_size.y - PANEL_MARGIN
	position = Vector2(x, y)
	if _tower and is_instance_valid(_tower):
		_last_screen_pos = _get_tower_screen_pos()


func _reposition_at(screen_pos: Vector2) -> void:
	var panel_size: Vector2 = size
	var viewport_size: Vector2 = Vector2(1280, 960)
	if get_viewport():
		var vp_rect: Rect2 = get_viewport().get_visible_rect()
		if vp_rect.size.x > 0 and vp_rect.size.y > 0:
			viewport_size = vp_rect.size

	# Preferred: right of tower
	var x: float = screen_pos.x + TOWER_OFFSET
	var y: float = screen_pos.y - panel_size.y * 0.5

	# Flip to left if it would go off the right edge
	if x + panel_size.x + PANEL_MARGIN > viewport_size.x:
		x = screen_pos.x - TOWER_OFFSET - panel_size.x

	# Clamp to viewport bounds
	y = clampf(y, PANEL_MARGIN, viewport_size.y - panel_size.y - PANEL_MARGIN)
	x = clampf(x, PANEL_MARGIN, viewport_size.x - panel_size.x - PANEL_MARGIN)

	position = Vector2(x, y)
	_last_screen_pos = screen_pos


func _process(_delta: float) -> void:
	if not visible or not _tower or not is_instance_valid(_tower):
		return
	if not _mobile_mode:
		# Desktop: reposition if tower screen pos changed (camera pan/zoom)
		var current_screen_pos: Vector2 = _get_tower_screen_pos()
		if current_screen_pos.distance_to(_last_screen_pos) > 2.0:
			_reposition_at(current_screen_pos)
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


func _on_ascend_pressed() -> void:
	if _tower and is_instance_valid(_tower):
		TowerSystem.ascend_tower(_tower)


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


func _on_tower_ascended(tower: Node) -> void:
	if tower == _tower:
		_refresh()


func _on_tower_fused(tower: Node) -> void:
	if tower == _tower:
		_refresh()


func _on_gold_changed(_new_amount: int) -> void:
	if visible and _tower and is_instance_valid(_tower):
		_refresh()


func _on_phase_changed(_new_phase: GameManager.GameState) -> void:
	if visible and _tower and is_instance_valid(_tower):
		_refresh()


func _on_fusion_failed(_tower_node: Node, _reason: String) -> void:
	if not visible or not fuse_button.visible:
		return
	_flash_fuse_button_red()


func _flash_fuse_button_red() -> void:
	var original_color: Color = fuse_button.modulate
	fuse_button.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(fuse_button, "modulate", original_color, 0.4)
