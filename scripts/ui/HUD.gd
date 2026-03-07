extends Control

## Top bar HUD: wave counter, lives, gold, build timer.

@onready var wave_label: Label = $TopBar/WaveLabel
@onready var topbar_timer_label: Label = $TopBar/TopBarTimerLabel
@onready var lives_label: Label = $TopBar/LivesLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var xp_label: Label = $TopBar/XPLabel
@onready var timer_label: Label = $WaveControls/TimerLabel
@onready var speed_button: Button = $TopBar/SpeedButton
@onready var codex_button: Button = $TopBar/CodexButton
@onready var pause_button: Button = $TopBar/PauseButton
@onready var start_wave_button: Button = $WaveControls/StartWaveButton
@onready var wave_controls: HBoxContainer = $WaveControls
@onready var bonus_label: Label = $BonusLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var xp_notif_label: Label = $XPNotifLabel
@onready var boss_hp_bar: PanelContainer = $BossHPBar
@onready var boss_announcement: Control = $BossAnnouncement
@onready var wave_progress_bar: ProgressBar = $WaveProgressBar
@onready var enemy_count_label: Label = $WaveControls/EnemyCountLabel
@onready var overtime_label: Label = $OvertimeLabel

const SPEEDS: Array[float] = [1.0, 1.5, 2.0, 0.5]
const SPEED_LABELS: Array[String] = ["1x", "1.5x", "2x", "0.5x"]

var _speed_index: int = 0
var _countdown_tween: Tween = null
var _run_xp: int = 0
var _is_mobile: bool = false
var _overflow_button: Button = null
var _overflow_menu: PanelContainer = null
var _overflow_dimmer: ColorRect = null


func _ready() -> void:
	UIManager.register_hud(self)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_completed.connect(_on_wave_completed)
	GameManager.early_wave_bonus.connect(_on_early_wave_bonus)
	EnemySystem.enemy_killed.connect(_on_enemy_killed)
	EnemySystem.enemy_spawned.connect(_on_boss_enemy_spawned)
	EnemySystem.enemy_killed.connect(_on_boss_enemy_killed)
	EnemySystem.wave_cleared.connect(_on_boss_wave_cleared)
	GameManager.wave_started.connect(_on_boss_wave_started)
	GameManager.wave_completed.connect(_on_xp_wave_completed)
	codex_button.pressed.connect(_on_codex_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	GameManager.speed_changed.connect(_on_speed_changed)
	GameManager.overtime_started.connect(_on_overtime_started)
	GameManager.lives_changed.connect(_on_lives_changed)
	countdown_label.visible = false
	xp_notif_label.visible = false
	if overtime_label:
		overtime_label.visible = false
	_update_speed_display()
	update_display()
	if UIManager.is_mobile():
		_apply_mobile_sizing()


func _apply_mobile_sizing() -> void:
	_is_mobile = true
	var top_bar: HBoxContainer = $TopBar
	top_bar.custom_minimum_size.y = UIManager.MOBILE_TOPBAR_HEIGHT

	# Hide labels that move to overflow or merge into wave counter on mobile
	xp_label.visible = false
	topbar_timer_label.visible = false
	codex_button.visible = false
	pause_button.visible = false

	# Speed button stays in bar, sized to fit 48px bar height
	speed_button.custom_minimum_size = Vector2(80, 44)
	start_wave_button.custom_minimum_size = UIManager.MOBILE_START_WAVE_MIN

	# Top bar info labels: expand to fill, clip text to prevent overflow
	var body_size: int = UIManager.MOBILE_FONT_SIZE_BODY
	for label: Label in [wave_label, topbar_timer_label, lives_label, gold_label, xp_label]:
		label.add_theme_font_size_override("font_size", body_size)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true

	# Buttons should NOT expand (fixed width)
	speed_button.size_flags_horizontal = 0
	codex_button.size_flags_horizontal = 0
	pause_button.size_flags_horizontal = 0

	# WaveControls area: proportional height increase
	wave_controls.custom_minimum_size.y = UIManager.MOBILE_BUTTON_MIN.y
	timer_label.add_theme_font_size_override("font_size", body_size)
	enemy_count_label.add_theme_font_size_override("font_size", body_size)

	# Countdown label: scale up from desktop 64 to 80 for mobile readability
	countdown_label.add_theme_font_size_override("font_size", 80)

	# Notification labels
	bonus_label.add_theme_font_size_override("font_size", maxi(32, body_size))
	xp_notif_label.add_theme_font_size_override("font_size", body_size)
	overtime_label.add_theme_font_size_override("font_size", maxi(28, body_size))

	# Strip keyboard hints -- not useful on mobile
	codex_button.text = "Codex"
	start_wave_button.text = "Start Wave"

	# Create overflow menu for codex/pause access
	_create_overflow_menu()


func _create_overflow_menu() -> void:
	var top_bar: HBoxContainer = $TopBar

	# Overflow icon button in the TopBar
	_overflow_button = Button.new()
	_overflow_button.text = "\u2261"
	_overflow_button.custom_minimum_size = Vector2(48, 44)
	_overflow_button.pressed.connect(_toggle_overflow_menu)
	top_bar.add_child(_overflow_button)

	# Invisible full-screen dimmer for click-outside-dismiss
	_overflow_dimmer = ColorRect.new()
	_overflow_dimmer.color = Color(0, 0, 0, 0)
	_overflow_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overflow_dimmer.visible = false
	_overflow_dimmer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_overflow_dimmer.gui_input.connect(_on_dimmer_input)
	add_child(_overflow_dimmer)

	# Overflow menu panel (child of HUD, not TopBar)
	_overflow_menu = PanelContainer.new()
	_overflow_menu.visible = false
	_overflow_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_overflow_menu.position = Vector2(size.x - 200, UIManager.MOBILE_TOPBAR_HEIGHT)

	var vbox := VBoxContainer.new()
	_overflow_menu.add_child(vbox)

	var menu_codex := Button.new()
	menu_codex.text = "Codex"
	menu_codex.custom_minimum_size = Vector2(200, 48)
	menu_codex.pressed.connect(func() -> void:
		_dismiss_overflow_menu()
		_on_codex_pressed()
	)
	vbox.add_child(menu_codex)

	var menu_pause := Button.new()
	menu_pause.text = "Pause"
	menu_pause.custom_minimum_size = Vector2(200, 48)
	menu_pause.pressed.connect(func() -> void:
		_dismiss_overflow_menu()
		_on_pause_pressed()
	)
	vbox.add_child(menu_pause)

	add_child(_overflow_menu)


func _toggle_overflow_menu() -> void:
	if _overflow_menu == null:
		return
	var show := not _overflow_menu.visible
	_overflow_menu.visible = show
	_overflow_dimmer.visible = show


func _dismiss_overflow_menu() -> void:
	if _overflow_menu:
		_overflow_menu.visible = false
	if _overflow_dimmer:
		_overflow_dimmer.visible = false


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_overflow_menu()


func update_display() -> void:
	wave_label.text = "Wave %d/%d" % [GameManager.current_wave, GameManager.max_waves]
	lives_label.text = "Lives: %d" % GameManager.lives
	gold_label.text = "Gold: %d" % EconomyManager.gold
	xp_label.text = "XP: %d" % _run_xp
	wave_controls.visible = GameManager.game_state == GameManager.GameState.BUILD_PHASE
	if wave_progress_bar:
		wave_progress_bar.max_value = GameManager.max_waves
		wave_progress_bar.value = GameManager.current_wave


func _process(_delta: float) -> void:
	if GameManager.game_state == GameManager.GameState.BUILD_PHASE:
		if enemy_count_label:
			enemy_count_label.visible = false
		if GameManager.current_wave == 1:
			# Wave 1: no auto-start timer, show prompt instead
			timer_label.text = "Place towers!"
			timer_label.visible = true
			countdown_label.visible = false
			# No topbar timer for wave 1 build phase
			topbar_timer_label.text = ""
			topbar_timer_label.visible = false
		else:
			var t: float = GameManager._build_timer
			timer_label.text = "Next wave in: %ds" % ceili(t)
			timer_label.visible = true
			# Persistent topbar timer
			topbar_timer_label.text = "Next: %ds" % ceili(t)
			topbar_timer_label.visible = true
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
		# Show enemy remaining count, hide timer
		timer_label.visible = false
		var remaining: int = EnemySystem.get_active_enemy_count() + EnemySystem.get_queued_enemy_count()
		if enemy_count_label:
			enemy_count_label.text = "%d remaining" % remaining
			enemy_count_label.visible = true

		if GameManager._overtime_active:
			# Overtime: show elapsed overtime time and pulsing warning
			var ot: float = GameManager._overtime_elapsed
			topbar_timer_label.text = "OVERTIME: %ds" % ceili(ot)
			topbar_timer_label.visible = true
			topbar_timer_label.add_theme_color_override("font_color",
				Color(1.0, 0.2, 0.15, 1.0))
			# Pulse the overtime label
			if overtime_label:
				overtime_label.visible = true
				var pulse: float = 0.7 + 0.3 * abs(sin(ot * TAU * 0.8))
				overtime_label.modulate = Color(1, 1, 1, pulse)
			countdown_label.visible = false
			countdown_label.scale = Vector2.ONE
		else:
			# Normal combat: persistent topbar timer
			var t: float = GameManager._combat_timer
			topbar_timer_label.text = "Time: %ds" % ceili(t)
			topbar_timer_label.visible = true
			topbar_timer_label.remove_theme_color_override("font_color")
			if overtime_label:
				overtime_label.visible = false
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
		if enemy_count_label:
			enemy_count_label.visible = false
		countdown_label.visible = false
		countdown_label.scale = Vector2.ONE
		topbar_timer_label.text = ""
		topbar_timer_label.visible = false
		if overtime_label:
			overtime_label.visible = false


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
	var no_leak: bool = GameManager._enemies_leaked_this_wave == 0
	var timed_out: bool = GameManager._previous_wave_timed_out
	if timed_out or not no_leak:
		return
	var bonus: int = EconomyManager.calculate_wave_bonus(wave_number, 0)
	var text: String = "+%dg Wave Bonus!" % bonus
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


func _on_pause_pressed() -> void:
	GameManager.toggle_pause()


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


func _on_boss_enemy_spawned(enemy: Node) -> void:
	if boss_hp_bar:
		boss_hp_bar.on_enemy_spawned(enemy)


func _on_boss_enemy_killed(enemy: Node) -> void:
	if boss_hp_bar:
		boss_hp_bar.on_enemy_killed(enemy)


func _on_boss_wave_cleared(wave_number: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.on_wave_cleared(wave_number)


func _on_boss_wave_started(wave_number: int) -> void:
	if boss_announcement:
		boss_announcement.on_wave_started(wave_number)


func _on_overtime_started() -> void:
	if overtime_label:
		overtime_label.visible = true
	update_display()


func _on_lives_changed(_new_lives: int) -> void:
	lives_label.text = "Lives: %d" % GameManager.lives
