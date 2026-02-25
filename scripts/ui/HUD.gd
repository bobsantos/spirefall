extends Control

## Top bar HUD: wave counter, lives, gold, build timer.

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var lives_label: Label = $TopBar/LivesLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var xp_label: Label = $TopBar/XPLabel
@onready var timer_label: Label = $WaveControls/TimerLabel
@onready var speed_button: Button = $TopBar/SpeedButton
@onready var codex_button: Button = $TopBar/CodexButton
@onready var start_wave_button: Button = $WaveControls/StartWaveButton
@onready var wave_controls: HBoxContainer = $WaveControls
@onready var bonus_label: Label = $BonusLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var xp_notif_label: Label = $XPNotifLabel

const SPEEDS: Array[float] = [1.0, 1.5, 2.0, 0.5]
const SPEED_LABELS: Array[String] = ["1x", "1.5x", "2x", "0.5x"]

var _speed_index: int = 0
var _countdown_tween: Tween = null
var _run_xp: int = 0


func _ready() -> void:
	UIManager.register_hud(self)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.early_wave_bonus.connect(_on_early_wave_bonus)
	EnemySystem.enemy_killed.connect(_on_enemy_killed)
	GameManager.wave_completed.connect(_on_xp_wave_completed)
	codex_button.pressed.connect(_on_codex_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	GameManager.speed_changed.connect(_on_speed_changed)
	countdown_label.visible = false
	xp_notif_label.visible = false
	_update_speed_display()
	update_display()


func update_display() -> void:
	wave_label.text = "Wave %d/%d" % [GameManager.current_wave, GameManager.max_waves]
	lives_label.text = "Lives: %d" % GameManager.lives
	gold_label.text = "Gold: %d" % EconomyManager.gold
	xp_label.text = "XP: %d" % _run_xp
	wave_controls.visible = GameManager.game_state == GameManager.GameState.BUILD_PHASE


func _process(_delta: float) -> void:
	if GameManager.game_state == GameManager.GameState.BUILD_PHASE:
		if GameManager.current_wave == 1:
			# Wave 1: no auto-start timer, show prompt instead
			timer_label.text = "Place towers!"
			timer_label.visible = true
			countdown_label.visible = false
		else:
			var t: float = GameManager._build_timer
			timer_label.text = "%.0f" % t
			timer_label.visible = true
			# Prominent centered countdown for last 5 seconds
			if t <= 5.0 and t > 0.0:
				countdown_label.text = "%d" % ceili(t)
				countdown_label.visible = true
				# Pulse red when urgent
				var urgency: float = 1.0 - (t / 5.0)
				countdown_label.add_theme_color_override("font_color",
					Color(1.0, 1.0 - urgency * 0.7, 1.0 - urgency * 0.8, 1.0))
				# Scale pulse effect
				var pulse: float = 1.0 + 0.15 * sin(t * TAU * 2.0)
				countdown_label.scale = Vector2(pulse, pulse)
			else:
				countdown_label.visible = false
				countdown_label.scale = Vector2.ONE
	elif GameManager.game_state == GameManager.GameState.COMBAT_PHASE:
		# Show combat timer countdown
		var t: float = GameManager._combat_timer
		timer_label.text = "%.0f" % maxf(t, 0.0)
		timer_label.visible = true
		# Prominent countdown for last 10 seconds of combat
		if t <= 10.0 and t > 0.0:
			countdown_label.text = "%d" % ceili(t)
			countdown_label.visible = true
			var urgency: float = 1.0 - (t / 10.0)
			countdown_label.add_theme_color_override("font_color",
				Color(1.0, 1.0 - urgency * 0.5, 1.0 - urgency * 0.7, 1.0))
			var pulse: float = 1.0 + 0.1 * sin(t * TAU * 1.5)
			countdown_label.scale = Vector2(pulse, pulse)
		else:
			countdown_label.visible = false
			countdown_label.scale = Vector2.ONE
	else:
		timer_label.visible = false
		countdown_label.visible = false
		countdown_label.scale = Vector2.ONE


func _on_gold_changed(_new_amount: int) -> void:
	update_display()


func _on_phase_changed(_new_phase: GameManager.GameState) -> void:
	# Reset XP tally at the start of a new game (wave 1, build phase)
	if _new_phase == GameManager.GameState.BUILD_PHASE and GameManager.current_wave == 1:
		_run_xp = 0
	update_display()


func _on_wave_started(_wave: int) -> void:
	update_display()


func _on_wave_completed(wave_number: int) -> void:
	var bonus: int = EconomyManager.calculate_wave_bonus(
		wave_number, GameManager._enemies_leaked_this_wave
	)
	var no_leak: bool = GameManager._enemies_leaked_this_wave == 0
	var text: String = "+%dg Wave Bonus!" % bonus
	if no_leak:
		text += "\nNo Leaks!"
	_show_bonus_notification(text)


func _show_bonus_notification(text: String) -> void:
	bonus_label.text = text
	bonus_label.visible = true
	bonus_label.modulate = Color(1, 1, 1, 1)
	var start_y: float = bonus_label.get_parent_area_size().y * 0.5 - 30
	bonus_label.position.y = start_y
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(bonus_label, "modulate:a", 0.0, 2.0).set_delay(1.0)
	tween.tween_property(bonus_label, "position:y", start_y - 40.0, 3.0)
	tween.chain().tween_callback(func() -> void: bonus_label.visible = false)


func _on_enemy_killed(_enemy: Node) -> void:
	_run_xp += 1
	xp_label.text = "XP: %d" % _run_xp
	_show_xp_notification()


func _on_xp_wave_completed(wave_number: int) -> void:
	_run_xp += wave_number * 10
	xp_label.text = "XP: %d" % _run_xp


func _show_xp_notification() -> void:
	xp_notif_label.text = "+1 XP"
	xp_notif_label.visible = true
	xp_notif_label.modulate = Color(1, 1, 1, 1)
	if is_inside_tree():
		var tween: Tween = create_tween()
		tween.tween_property(xp_notif_label, "modulate:a", 0.0, 0.8)
		tween.tween_callback(func() -> void: xp_notif_label.visible = false)


func _on_early_wave_bonus(amount: int) -> void:
	_show_bonus_notification("+%dg Early Start!" % amount)


func _on_codex_pressed() -> void:
	UIManager.toggle_codex()


func _on_start_wave_pressed() -> void:
	GameManager.start_wave_early()


func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	GameManager.set_game_speed(SPEEDS[_speed_index])


func _on_speed_changed(speed: float) -> void:
	# Sync index to match the speed (handles external resets like start_game)
	for i: int in range(SPEEDS.size()):
		if is_equal_approx(SPEEDS[i], speed):
			_speed_index = i
			break
	_update_speed_display()


func _update_speed_display() -> void:
	speed_button.text = SPEED_LABELS[_speed_index]
	if is_equal_approx(SPEEDS[_speed_index], 1.0):
		speed_button.self_modulate = Color.WHITE
	else:
		speed_button.self_modulate = Color.YELLOW
