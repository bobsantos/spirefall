extends Control

## Bottom panel: scrollable row of tower build buttons grouped by element.

signal tower_build_selected(tower_data: TowerData)

@onready var button_container: HBoxContainer = $ScrollContainer/HBoxContainer

var _tower_buttons: Array[Button] = []
var _available_towers: Array[TowerData] = []

# Canonical element order for build menu button layout
const ELEMENT_ORDER: Array[String] = ["fire", "water", "earth", "wind", "lightning", "ice"]


func _ready() -> void:
	UIManager.register_build_menu(self)
	_load_available_towers()
	_create_buttons()


func _load_available_towers() -> void:
	# Load all tier-1 base towers
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
	for tower: TowerData in _available_towers:
		var btn := Button.new()
		btn.text = "%s\n%dg" % [tower.tower_name, tower.cost]
		btn.custom_minimum_size = Vector2(80, 64)
		btn.pressed.connect(_on_tower_selected.bind(tower))
		button_container.add_child(btn)
		_tower_buttons.append(btn)


func _on_tower_selected(tower_data: TowerData) -> void:
	UIManager.request_build(tower_data)
	tower_build_selected.emit(tower_data)


func _process(_delta: float) -> void:
	# Gray out buttons player can't afford
	for i: int in range(_available_towers.size()):
		if i < _tower_buttons.size():
			_tower_buttons[i].disabled = not EconomyManager.can_afford(_available_towers[i].cost)
