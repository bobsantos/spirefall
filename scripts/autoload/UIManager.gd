class_name UIManagerClass
extends Node

## Coordinates all UI elements: HUD, build menu, tower info, wave preview.

signal tower_selected(tower: Node)
signal tower_deselected()
signal build_requested(tower_data: TowerData)

var selected_tower: Node = null
var hud: Control = null
var build_menu: Control = null
var tower_info_panel: Control = null
var wave_preview_panel: Control = null


func register_hud(hud_node: Control) -> void:
	hud = hud_node


func register_build_menu(menu_node: Control) -> void:
	build_menu = menu_node


func register_tower_info_panel(panel_node: Control) -> void:
	tower_info_panel = panel_node


func register_wave_preview(panel_node: Control) -> void:
	wave_preview_panel = panel_node


func select_tower(tower: Node) -> void:
	selected_tower = tower
	tower_selected.emit(tower)
	if tower_info_panel:
		tower_info_panel.show()
		tower_info_panel.display_tower(tower)


func deselect_tower() -> void:
	selected_tower = null
	tower_deselected.emit()
	if tower_info_panel:
		tower_info_panel.hide()


func request_build(tower_data: TowerData) -> void:
	build_requested.emit(tower_data)


func update_hud() -> void:
	if hud:
		hud.update_display()


func show_wave_preview(wave_number: int) -> void:
	if wave_preview_panel:
		wave_preview_panel.display_wave(wave_number)
