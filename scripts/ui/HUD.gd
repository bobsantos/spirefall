extends Control

## Top bar HUD: wave counter, lives, gold, build timer.

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var lives_label: Label = $TopBar/LivesLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var start_wave_button: Button = $TopBar/StartWaveButton


func _ready() -> void:
	UIManager.register_hud(self)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.wave_started.connect(_on_wave_started)
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


func _on_start_wave_pressed() -> void:
	GameManager.start_wave_early()
