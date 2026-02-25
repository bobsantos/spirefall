class_name GameOverScreen
extends Control

## Full-screen overlay shown on victory or defeat. Displays result, run stats,
## and buttons to restart or return to the main menu.

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var result_label: Label = $CenterContainer/PanelContainer/VBoxContainer/ResultLabel
@onready var waves_label: Label = $CenterContainer/PanelContainer/VBoxContainer/WavesLabel
@onready var enemies_killed_label: Label = $CenterContainer/PanelContainer/VBoxContainer/EnemiesKilledLabel
@onready var gold_earned_label: Label = $CenterContainer/PanelContainer/VBoxContainer/GoldEarnedLabel
@onready var time_played_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TimePlayedLabel
@onready var xp_earned_label: Label = $CenterContainer/PanelContainer/VBoxContainer/XPEarnedLabel
@onready var unlocks_label: Label = $CenterContainer/PanelContainer/VBoxContainer/UnlocksLabel
@onready var play_again_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/PlayAgainButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/MainMenuButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	GameManager.game_over.connect(_on_game_over)
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func _on_game_over(victory: bool) -> void:
	if victory:
		result_label.text = "Victory!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	else:
		result_label.text = "Defeat!"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

	var stats: Dictionary = GameManager.run_stats
	waves_label.text = "Waves Survived: %d / %d" % [GameManager.current_wave, GameManager.max_waves]
	enemies_killed_label.text = "Enemies Killed: %d" % stats.get("enemies_killed", 0)
	gold_earned_label.text = "Gold Earned: %d" % stats.get("total_gold_earned", 0)
	time_played_label.text = "Time: %s" % _format_time(stats.get("elapsed_time", 0))

	# Show actual XP earned from MetaProgression formula
	var xp: int = MetaProgression.calculate_run_xp(stats)
	xp_earned_label.text = "XP Earned: %d" % xp

	# Show new unlocks if any were earned this run
	var xp_before: int = MetaProgression.get_total_xp() - xp
	var new_unlocks: Array[String] = MetaProgression.get_new_unlocks(xp_before, MetaProgression.get_total_xp())
	if new_unlocks.is_empty():
		unlocks_label.visible = false
	else:
		var unlock_names: PackedStringArray = PackedStringArray()
		for id: String in new_unlocks:
			unlock_names.append(_format_unlock_name(id))
		unlocks_label.text = "New Unlock: %s" % ", ".join(unlock_names)
		unlocks_label.visible = true

	visible = true


func _on_play_again_pressed() -> void:
	# Unpause before transitioning so the new scene processes normally
	GameManager.unpause()
	SceneManager.restart_game()


func _on_main_menu_pressed() -> void:
	# Unpause before transitioning so the new scene processes normally
	GameManager.unpause()
	SceneManager.go_to_main_menu()


## Format milliseconds as mm:ss.
func _format_time(ms: int) -> String:
	var total_seconds: int = ms / 1000
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


## Convert unlock ID (e.g. "mode_draft") to display name (e.g. "Draft Mode").
func _format_unlock_name(unlock_id: String) -> String:
	match unlock_id:
		"mode_draft": return "Draft Mode"
		"mode_endless": return "Endless Mode"
		"map_mountain_pass": return "Mountain Pass"
		"map_river_delta": return "River Delta"
		"map_volcanic_caldera": return "Volcanic Caldera"
		_: return unlock_id.replace("_", " ").capitalize()
