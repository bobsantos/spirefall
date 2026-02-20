class_name SceneManagerClass
extends Node

## Manages scene transitions with fade-to-black overlay.
## Stores game configuration that persists across scene changes.

signal scene_changing()

const FADE_DURATION: float = 0.3
const MAIN_MENU_PATH: String = "res://scenes/main/MainMenu.tscn"
const GAME_PATH: String = "res://scenes/main/Game.tscn"

var current_game_config: Dictionary = {}
var is_transitioning: bool = false

var _canvas_layer: CanvasLayer
var _overlay: ColorRect
var _tween: Tween
var _last_scene_path: String = ""


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_overlay)


func change_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	if is_transitioning:
		return

	is_transitioning = true
	_last_scene_path = scene_path
	scene_changing.emit()

	_perform_transition(scene_path)


func go_to_main_menu() -> void:
	current_game_config = {}
	change_scene(MAIN_MENU_PATH)


func go_to_game(config: Dictionary) -> void:
	current_game_config = config
	change_scene(GAME_PATH)


func restart_game() -> void:
	change_scene(GAME_PATH)


func _perform_transition(scene_path: String) -> void:
	# Fade out (to black)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	await _tween.finished

	# Change scene
	get_tree().change_scene_to_file(scene_path)

	# Wait one frame for the new scene to initialize
	await get_tree().process_frame

	# Fade in (from black)
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)
	await _tween.finished

	is_transitioning = false
