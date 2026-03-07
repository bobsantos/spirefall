class_name TowerActionRing
extends Control

## Kingdom Rush-style radial action ring for selected towers.
## Circular buttons appear in a semicircle around the tower.

signal fuse_requested(tower: Node)

var _tower: Node = null
var _buttons: Array[Control] = []
var _mobile_mode: bool = false
var _last_screen_pos: Vector2 = Vector2.ZERO

# Desktop sizing
const BUTTON_DIAMETER_DESKTOP: float = 48.0
const RING_RADIUS_DESKTOP: float = 80.0
# Mobile sizing
const BUTTON_DIAMETER_MOBILE: float = 64.0
const RING_RADIUS_MOBILE: float = 100.0

const BORDER_WIDTH: float = 3.0

# Action border colors
const COLOR_UPGRADE := Color(0.3, 0.69, 0.31)
const COLOR_SELL := Color(0.96, 0.26, 0.21)
const COLOR_ASCEND := Color(1.0, 0.84, 0.0)
const COLOR_FUSE := Color(0.61, 0.15, 0.69)

# Button background
const BG_COLOR := Color(0.1, 0.1, 0.12, 0.85)


func _ready() -> void:
	UIManager.register_tower_info_panel(self)
	_mobile_mode = UIManager.is_mobile()
	visible = false
	# Full-screen overlay so we can catch clicks outside the ring
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	TowerSystem.tower_upgraded.connect(_on_tower_changed)
	TowerSystem.tower_ascended.connect(_on_tower_changed)
	TowerSystem.tower_fused.connect(_on_tower_changed)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	TowerSystem.fusion_failed.connect(_on_fusion_failed)


func display_tower(tower: Node) -> void:
	_tower = tower
	if _mobile_mode:
		if UIManager.build_menu and UIManager.build_menu.has_method("slide_out"):
			UIManager.build_menu.slide_out()
	visible = true
	_refresh()


func hide_ring() -> void:
	_tower = null
	visible = false
	_clear_buttons()


func _refresh() -> void:
	if not _tower or not is_instance_valid(_tower):
		return
	_clear_buttons()

	var actions: Array[Dictionary] = _get_actions()
	for action: Dictionary in actions:
		var btn: Control = _create_action_button(action)
		add_child(btn)
		_buttons.append(btn)

	_position_buttons()


func _get_actions() -> Array[Dictionary]:
	## Build ordered list of available actions (left to right: Sell, Fuse, Upgrade, Ascend)
	var data: TowerData = _tower.tower_data
	var actions: Array[Dictionary] = []

	# Sell -- always shown
	var refund_pct: float = 0.75 if GameManager.game_state == GameManager.GameState.BUILD_PHASE else 0.50
	var refund: int = int(data.cost * refund_pct)
	actions.append({
		"type": "sell",
		"cost_text": "%dg" % refund,
		"border_color": COLOR_SELL,
		"callback": _on_sell,
	})

	# Fuse -- if has fusion partners
	var fuse_info: Dictionary = _get_fuse_info(data)
	if fuse_info.get("show", false):
		actions.append({
			"type": "fuse",
			"cost_text": fuse_info.get("cost_text", ""),
			"border_color": COLOR_FUSE,
			"callback": _on_fuse,
		})

	# Upgrade -- if upgrade path exists
	if data.upgrade_to != null:
		var cost: int = data.upgrade_to.cost - data.cost
		var can_afford: bool = EconomyManager.can_afford(cost)
		actions.append({
			"type": "upgrade",
			"cost_text": "%dg" % cost,
			"border_color": COLOR_UPGRADE,
			"callback": _on_upgrade,
			"disabled": not can_afford,
		})

	# Ascend -- if superior + ascend path exists
	var is_superior: bool = TowerSystem._is_superior(_tower) and not TowerSystem._is_ascended(_tower)
	var has_path: bool = data.element in TowerSystem.ASCENDED_PATHS
	if is_superior and has_path:
		var can: bool = TowerSystem.can_ascend(_tower)
		actions.append({
			"type": "ascend",
			"cost_text": "%dg" % TowerSystem.ASCEND_COST,
			"border_color": COLOR_ASCEND,
			"callback": _on_ascend,
			"disabled": not can,
		})

	return actions


func _get_fuse_info(data: TowerData) -> Dictionary:
	## Calculate fusion availability and cost display text.
	var can_dual: bool = data.tier == 1 and data.upgrade_to == null and not data.tower_name.ends_with(" Ascended")
	var can_legendary: bool = data.tier == 2

	var costs: Array[int] = []
	var has_partners: bool = false

	if can_dual:
		var partners: Array[Node] = FusionRegistry.get_fusion_partners(_tower)
		for partner: Node in partners:
			var cost: int = FusionRegistry.get_fusion_cost(data.element, partner.tower_data.element)
			if cost > 0 and cost not in costs:
				costs.append(cost)
		# Also check if this superior can participate in a legendary fusion
		var leg_partners: Array[Node] = FusionRegistry.get_legendary_partners(_tower)
		for partner: Node in leg_partners:
			if partner.tower_data.tier == 2:
				var cost: int = FusionRegistry.get_legendary_cost(partner.tower_data.fusion_elements, data.element)
				if cost > 0 and cost not in costs:
					costs.append(cost)
		has_partners = partners.size() > 0 or leg_partners.size() > 0

	if can_legendary:
		var partners: Array[Node] = FusionRegistry.get_legendary_partners(_tower)
		for partner: Node in partners:
			var cost: int = FusionRegistry.get_legendary_cost(data.fusion_elements, partner.tower_data.element)
			if cost > 0 and cost not in costs:
				costs.append(cost)
		has_partners = has_partners or partners.size() > 0

	if not has_partners:
		return {"show": false}

	costs.sort()
	var cost_text: String = ""
	if costs.size() == 1:
		cost_text = "%dg" % costs[0]
	elif costs.size() > 1:
		cost_text = "%dg" % costs[0]
	else:
		cost_text = "Fuse"

	return {"show": true, "cost_text": cost_text}


func _create_action_button(action: Dictionary) -> Control:
	## Create a circular button with drawn icon and cost label.
	var diameter: float = BUTTON_DIAMETER_MOBILE if _mobile_mode else BUTTON_DIAMETER_DESKTOP
	var btn := RingButton.new()
	btn.custom_minimum_size = Vector2(diameter, diameter)
	btn.size = Vector2(diameter, diameter)
	btn.action_type = action["type"]
	btn.border_color = action["border_color"]
	btn.cost_text = action["cost_text"]
	btn.diameter = diameter
	btn.is_disabled = action.get("disabled", false)

	if _mobile_mode:
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.gui_input.connect(_on_button_gui_input.bind(action))

	return btn


func _on_button_gui_input(event: InputEvent, action: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var callback: Callable = action["callback"]
		if not action.get("disabled", false):
			callback.call()


func _get_button_angles(count: int) -> Array[float]:
	## Return angles in radians for buttons in the top semicircle.
	## Angles measured clockwise from north (up = -PI/2 in Godot coords).
	var angles: Array[float] = []
	match count:
		2:
			angles = [deg_to_rad(-45.0), deg_to_rad(45.0)]
		3:
			angles = [deg_to_rad(-60.0), deg_to_rad(0.0), deg_to_rad(60.0)]
		4:
			angles = [deg_to_rad(-90.0), deg_to_rad(-30.0), deg_to_rad(30.0), deg_to_rad(90.0)]
		1:
			angles = [deg_to_rad(0.0)]
	return angles


func _position_buttons() -> void:
	if not _tower or not is_instance_valid(_tower) or _buttons.is_empty():
		return

	var screen_pos: Vector2 = _tower.get_global_transform_with_canvas().origin
	_last_screen_pos = screen_pos

	var ring_radius: float = RING_RADIUS_MOBILE if _mobile_mode else RING_RADIUS_DESKTOP
	var btn_radius: float = (BUTTON_DIAMETER_MOBILE if _mobile_mode else BUTTON_DIAMETER_DESKTOP) / 2.0

	var viewport_size: Vector2 = Vector2(1280, 960)
	if get_viewport():
		var vp_rect: Rect2 = get_viewport().get_visible_rect()
		if vp_rect.size.x > 0 and vp_rect.size.y > 0:
			viewport_size = vp_rect.size

	# Determine if we need to flip to bottom semicircle
	var flip_y: bool = screen_pos.y < ring_radius + btn_radius + 10.0

	var angles: Array[float] = _get_button_angles(_buttons.size())

	# Compute ring center (may shift for edge clamping)
	var ring_center: Vector2 = screen_pos

	for i: int in range(_buttons.size()):
		var angle: float = angles[i]
		# Convert angle from "clockwise from north" to Godot's coordinate system
		# North = -Y, so angle 0 = straight up = -PI/2 in standard math
		# Clockwise from north: actual_angle = -PI/2 + angle
		var actual_angle: float = -PI / 2.0 + angle
		if flip_y:
			# Flip: mirror around horizontal = negate the Y component
			actual_angle = PI / 2.0 - angle

		var offset: Vector2 = Vector2(cos(actual_angle), sin(actual_angle)) * ring_radius
		var btn_pos: Vector2 = ring_center + offset

		# Edge clamp individual button positions
		btn_pos.x = clampf(btn_pos.x, btn_radius, viewport_size.x - btn_radius)
		btn_pos.y = clampf(btn_pos.y, btn_radius, viewport_size.y - btn_radius)

		# Position button (centered on btn_pos)
		_buttons[i].position = btn_pos - Vector2(btn_radius, btn_radius)


func _process(_delta: float) -> void:
	if not visible or not _tower or not is_instance_valid(_tower):
		return
	var current_screen_pos: Vector2 = _tower.get_global_transform_with_canvas().origin
	if current_screen_pos.distance_to(_last_screen_pos) > 2.0:
		_position_buttons()


func _clear_buttons() -> void:
	for btn: Control in _buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_buttons.clear()


# --- Action handlers ---

func _on_upgrade() -> void:
	if _tower and is_instance_valid(_tower):
		TowerSystem.upgrade_tower(_tower)


func _on_sell() -> void:
	if _tower and is_instance_valid(_tower):
		TowerSystem.sell_tower(_tower)
		UIManager.deselect_tower()


func _on_ascend() -> void:
	if _tower and is_instance_valid(_tower):
		TowerSystem.ascend_tower(_tower)


func _on_fuse() -> void:
	if _tower and is_instance_valid(_tower):
		fuse_requested.emit(_tower)


# --- Signal handlers ---

func _on_tower_changed(tower: Node) -> void:
	if tower == _tower:
		_refresh()


func _on_gold_changed(_new_amount: int) -> void:
	if visible and _tower and is_instance_valid(_tower):
		_refresh()


func _on_phase_changed(_new_phase: GameManager.GameState) -> void:
	if visible and _tower and is_instance_valid(_tower):
		_refresh()


func _on_fusion_failed(_tower_node: Node, _reason: String) -> void:
	# Flash the fuse button red briefly
	for btn: Control in _buttons:
		if btn is RingButton and btn.action_type == "fuse":
			btn.modulate = Color(1.0, 0.3, 0.3, 1.0)
			var tween: Tween = create_tween()
			tween.tween_property(btn, "modulate", Color.WHITE, 0.4)


# --- Hit testing for mobile touch forwarding ---

func get_hit_button_action(screen_pos: Vector2) -> Callable:
	## Check if screen_pos hits any ring button. Returns the action callback or empty Callable.
	if not visible:
		return Callable()
	for btn: Control in _buttons:
		if not is_instance_valid(btn) or not btn.visible:
			continue
		if btn is RingButton and btn.is_disabled:
			continue
		var btn_center: Vector2 = btn.position + btn.size / 2.0
		var radius: float = btn.size.x / 2.0
		if screen_pos.distance_to(btn_center) <= radius:
			return btn.get_meta("callback", Callable())
	return Callable()


func hit_test_ring(screen_pos: Vector2) -> bool:
	## Return true if screen_pos hits any button in the ring (for touch forwarding).
	if not visible:
		return false
	for btn: Control in _buttons:
		if not is_instance_valid(btn) or not btn.visible:
			continue
		var btn_center: Vector2 = btn.position + btn.size / 2.0
		var radius: float = btn.size.x / 2.0
		if screen_pos.distance_to(btn_center) <= radius:
			return true
	return false


func try_invoke_ring_button(screen_pos: Vector2) -> bool:
	## If screen_pos hits a ring button, invoke its action and return true.
	if not visible:
		return false
	for i: int in range(_buttons.size()):
		var btn: Control = _buttons[i]
		if not is_instance_valid(btn) or not btn.visible:
			continue
		if btn is RingButton and btn.is_disabled:
			continue
		var btn_center: Vector2 = btn.position + btn.size / 2.0
		var radius: float = btn.size.x / 2.0
		if screen_pos.distance_to(btn_center) <= radius:
			# Find the matching action and call it
			var actions: Array[Dictionary] = _get_actions()
			if i < actions.size():
				var callback: Callable = actions[i]["callback"]
				callback.call()
			return true
	return false
