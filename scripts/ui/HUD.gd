extends Control

## Top bar HUD: wave counter, lives, gold, build timer.

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var lives_label: Label = $TopBar/LivesLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var codex_button: Button = $TopBar/CodexButton
@onready var start_wave_button: Button = $TopBar/StartWaveButton
@onready var bonus_label: Label = $BonusLabel


func _ready() -> void:
	UIManager.register_hud(self)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.early_wave_bonus.connect(_on_early_wave_bonus)
	codex_button.pressed.connect(_on_codex_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	update_display()


func update_display() -> void:
	wave_label.text = "Wave %d/%d" % [GameManager.current_wave, GameManager.max_waves]
	lives_label.text = "Lives: %d" % GameManager.lives
	gold_label.text = "Gold: %d" % EconomyManager.gold
	start_wave_button.visible = GameManager.game_state == GameManager.GameState.BUILD_PHASE


func _process(_delta: float) -> void:
	if GameManager.game_state == GameManager.GameState.BUILD_PHASE:
		timer_label.text = "%.0f" % GameManager._build_timer
		timer_label.visible = true
	else:
		timer_label.visible = false


func _on_gold_changed(_new_amount: int) -> void:
	update_display()


func _on_phase_changed(_new_phase: GameManager.GameState) -> void:
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


func _on_early_wave_bonus(amount: int) -> void:
	_show_bonus_notification("+%dg Early Start!" % amount)


func _on_codex_pressed() -> void:
	UIManager.toggle_codex()


func _on_start_wave_pressed() -> void:
	GameManager.start_wave_early()
