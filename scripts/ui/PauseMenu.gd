class_name PauseMenu
extends Control

## In-game pause overlay with semi-transparent background.
## Buttons: Resume, Restart, Settings (no-op until Task D3), Codex, Quit to Menu.
## process_mode is PROCESS_MODE_WHEN_PAUSED so it remains interactive while paused.
##
## All tree-pause calls are delegated to GameManager (an autoload always in the tree)
## so PauseMenu works correctly when tested outside the scene tree.

@onready var resume_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/PanelContainer/VBoxContainer/RestartButton
@onready var settings_button: Button = $CenterContainer/PanelContainer/VBoxContainer/SettingsButton
@onready var codex_button: Button = $CenterContainer/PanelContainer/VBoxContainer/CodexButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/QuitButton

## True while the Codex panel is open from this menu. Prevents _on_paused_changed
## from re-showing this overlay on top of the Codex when CodexPanel.toggle()
## re-emits paused_changed(true).
var _codex_open: bool = false


func _ready() -> void:
	# Must process while the scene tree is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# React to external pause state changes (e.g., Escape key in Game.gd)
	GameManager.paused_changed.connect(_on_paused_changed)


func _on_paused_changed(is_paused: bool) -> void:
	# Do not re-show this overlay while Codex is open; the Codex is drawn on top
	# of PauseMenu in the scene tree and must stay fully visible and interactive.
	if _codex_open:
		return
	visible = is_paused


## Show the pause overlay and pause the game tree.
func show_pause_menu() -> void:
	GameManager.pause()
	visible = true


## Hide the pause overlay and resume the game tree.
func hide_pause_menu() -> void:
	GameManager.unpause()
	visible = false


func _on_resume_pressed() -> void:
	GameManager.unpause()
	visible = false


func _on_restart_pressed() -> void:
	# Unpause before reloading so the new scene processes normally
	GameManager.unpause()
	SceneManager.restart_game()


func _on_settings_pressed() -> void:
	# SettingsPanel not yet implemented (Task D3). No-op for now.
	print("PauseMenu: Settings not yet available (Task D3).")


func _on_codex_pressed() -> void:
	# Hide this overlay and set the guard flag so _on_paused_changed does not
	# re-show it while the Codex is open. CodexPanel is rendered after PauseMenu
	# in Game.tscn's UILayer, so it always draws on top — the Codex is fully
	# visible and interactive once this overlay is hidden.
	if UIManager.codex_panel and UIManager.codex_panel.has_method("toggle"):
		_codex_open = true
		visible = false
		# One-shot: restore this overlay once the Codex emits `closed`.
		if not UIManager.codex_panel.closed.is_connected(_on_codex_closed):
			UIManager.codex_panel.closed.connect(_on_codex_closed, CONNECT_ONE_SHOT)
		UIManager.toggle_codex()


func _on_codex_closed() -> void:
	# The game is still paused; clear the guard and bring the pause overlay back.
	_codex_open = false
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	# Handle Escape/ui_cancel while this overlay is visible and the tree is paused.
	# Game.gd cannot receive input while paused (it has no PROCESS_MODE_WHEN_PAUSED),
	# so PauseMenu owns the responsibility of closing itself via keyboard.
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		# get_viewport() is only safe when we are inside the scene tree.
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _on_quit_pressed() -> void:
	# Unpause before navigating so the new scene processes normally
	GameManager.unpause()
	SceneManager.go_to_main_menu()
