class_name UIManagerClass
extends Node

## Coordinates all UI elements: HUD, build menu, tower info, wave preview.

signal tower_selected(tower: Node)
signal tower_deselected()
signal build_requested(tower_data: TowerData)
signal placement_cancelled
signal placement_ended

## Systematic scale factor for mobile UI (1.5x desktop sizes).
const MOBILE_SCALE: float = 1.5

## Minimum touch-target sizes for mobile (px). Desktop uses default sizes.
const MOBILE_BUTTON_MIN: Vector2 = Vector2(64, 64)
const MOBILE_TOWER_BUTTON_MIN: Vector2 = Vector2(150, 100)
const MOBILE_ACTION_BUTTON_MIN_HEIGHT: float = 56.0
const MOBILE_START_WAVE_MIN: Vector2 = Vector2(160, 64)

## Mobile font sizes (minimum readable on phone screens).
const MOBILE_FONT_SIZE_BODY: int = 16
const MOBILE_FONT_SIZE_LABEL: int = 14
const MOBILE_FONT_SIZE_TITLE: int = 24

## Mobile layout dimensions (px).
const MOBILE_TOPBAR_HEIGHT: int = 72
const MOBILE_BUILD_MENU_HEIGHT: int = 140
const MOBILE_CARD_MIN_HEIGHT: int = 160

var selected_tower: Node = null
var hud: Control = null
var build_menu: Control = null
var tower_info_panel: Control = null
var wave_preview_panel: Control = null
var codex_panel: Control = null


func register_hud(hud_node: Control) -> void:
	hud = hud_node


func register_build_menu(menu_node: Control) -> void:
	build_menu = menu_node


func register_tower_info_panel(panel_node: Control) -> void:
	tower_info_panel = panel_node


func register_wave_preview(panel_node: Control) -> void:
	wave_preview_panel = panel_node


func register_codex(panel_node: Control) -> void:
	codex_panel = panel_node


func toggle_codex() -> void:
	if codex_panel and codex_panel.has_method("toggle"):
		codex_panel.toggle()


func select_tower(tower: Node) -> void:
	selected_tower = tower
	tower_selected.emit(tower)
	if wave_preview_panel:
		wave_preview_panel.hide()
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


func cancel_placement() -> void:
	placement_cancelled.emit()


func update_hud() -> void:
	if hud:
		hud.update_display()


func show_wave_preview(wave_number: int) -> void:
	if selected_tower:
		deselect_tower()
	if wave_preview_panel:
		wave_preview_panel.display_wave(wave_number)


## Returns true when running on a mobile device or mobile web browser.
static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
