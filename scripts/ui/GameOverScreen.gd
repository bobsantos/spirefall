class_name GameOverScreen
extends Control

## Full-screen overlay shown on victory or defeat. Displays result, stats, and
## a "Play Again" button that restarts the game scene.

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var result_label: Label = $CenterContainer/PanelContainer/VBoxContainer/ResultLabel
@onready var waves_label: Label = $CenterContainer/PanelContainer/VBoxContainer/WavesLabel
@onready var play_again_button: Button = $CenterContainer/PanelContainer/VBoxContainer/PlayAgainButton


func _ready() -> void:
	visible = false
	GameManager.game_over.connect(_on_game_over)
	play_again_button.pressed.connect(_on_play_again_pressed)


func _on_game_over(victory: bool) -> void:
	if victory:
		result_label.text = "Victory!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	else:
		result_label.text = "Defeat!"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

	waves_label.text = "Waves Survived: %d / %d" % [GameManager.current_wave, GameManager.max_waves]
	visible = true


func _on_play_again_pressed() -> void:
	# Reset manager state before reloading the scene
	EconomyManager.reset()
	get_tree().reload_current_scene()
