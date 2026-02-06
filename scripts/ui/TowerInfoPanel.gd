extends PanelContainer

## Shows selected tower stats with Upgrade and Sell buttons.

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var element_label: Label = $VBoxContainer/ElementLabel
@onready var damage_label: Label = $VBoxContainer/DamageLabel
@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var range_label: Label = $VBoxContainer/RangeLabel
@onready var special_label: Label = $VBoxContainer/SpecialLabel
@onready var upgrade_button: Button = $VBoxContainer/UpgradeButton
@onready var sell_button: Button = $VBoxContainer/SellButton

var _tower: Node = null


func _ready() -> void:
	UIManager.register_tower_info_panel(self)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	TowerSystem.tower_upgraded.connect(_on_tower_upgraded)


func display_tower(tower: Node) -> void:
	_tower = tower
	_refresh()


func _refresh() -> void:
	if not _tower or not is_instance_valid(_tower):
		return
	var data: TowerData = _tower.tower_data
	var next: TowerData = data.upgrade_to
	name_label.text = data.tower_name
	element_label.text = "Element: %s" % data.element.capitalize()
	damage_label.text = _stat_text("Damage", data.damage, next.damage if next else -1)
	speed_label.text = _stat_text_f("Speed", data.attack_speed, next.attack_speed if next else -1.0, "/s")
	range_label.text = _stat_text("Range", data.range_cells, next.range_cells if next else -1, " cells")
	if data.special_description != "":
		special_label.text = data.special_description
		if next and next.special_description != "" and next.special_description != data.special_description:
			special_label.text += "  ->  %s" % next.special_description
		special_label.visible = true
	else:
		special_label.visible = false
	_update_upgrade_button(data)
	_update_sell_button(data)


func _stat_text(label: String, current: int, next: int, suffix: String = "") -> String:
	if next > 0 and next != current:
		return "%s: %d  ->  %d%s" % [label, current, next, suffix]
	return "%s: %d%s" % [label, current, suffix]


func _stat_text_f(label: String, current: float, next: float, suffix: String = "") -> String:
	if next > 0.0 and not is_equal_approx(next, current):
		return "%s: %.1f  ->  %.1f%s" % [label, current, next, suffix]
	return "%s: %.1f%s" % [label, current, suffix]


func _update_upgrade_button(data: TowerData) -> void:
	if data.upgrade_to == null:
		upgrade_button.text = "Max Level"
		upgrade_button.disabled = true
	else:
		var cost: int = data.upgrade_to.cost - data.cost
		upgrade_button.text = "Upgrade (%dg)" % cost
		upgrade_button.disabled = not EconomyManager.can_afford(cost)


func _update_sell_button(data: TowerData) -> void:
	var refund_pct: float = 0.75 if GameManager.game_state == GameManager.GameState.BUILD_PHASE else 0.50
	var refund: int = int(data.cost * refund_pct)
	sell_button.text = "Sell (%dg)" % refund


func _process(_delta: float) -> void:
	# Keep upgrade button affordability up to date
	if visible and _tower and is_instance_valid(_tower):
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


func _on_tower_upgraded(tower: Node) -> void:
	if tower == _tower:
		_refresh()
