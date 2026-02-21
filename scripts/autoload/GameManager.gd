class_name GameManagerClass
extends Node

## Controls game state, phase transitions, wave flow, and win/lose conditions.

enum GameState { MENU, BUILD_PHASE, COMBAT_PHASE, INCOME_PHASE, GAME_OVER }
enum GameMode { CLASSIC, DRAFT, ENDLESS }

signal phase_changed(new_phase: GameState)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_over(victory: bool)
signal early_wave_bonus(amount: int)

@export var max_waves: int = 30
@export var starting_lives: int = 20
@export var build_phase_duration: float = 30.0

var current_wave: int = 0
var lives: int = 20
var game_state: GameState = GameState.MENU
var current_mode: GameMode = GameMode.CLASSIC

var _build_timer: float = 0.0
var _enemies_leaked_this_wave: int = 0

## Mode string to GameMode enum mapping.
const _MODE_MAP: Dictionary = {
	"classic": GameMode.CLASSIC,
	"draft": GameMode.DRAFT,
	"endless": GameMode.ENDLESS,
}


func _ready() -> void:
	lives = starting_lives


func start_game(mode: String = "classic") -> void:
	current_mode = _MODE_MAP.get(mode, GameMode.CLASSIC)
	if current_mode == GameMode.ENDLESS:
		max_waves = 999
	else:
		max_waves = 30
	current_wave = 0
	lives = starting_lives
	_transition_to(GameState.BUILD_PHASE)


func start_wave_early() -> void:
	if game_state == GameState.BUILD_PHASE:
		var bonus: int = int(_build_timer) * 10
		_transition_to(GameState.COMBAT_PHASE)
		EconomyManager.add_gold(bonus)
		if bonus > 0:
			early_wave_bonus.emit(bonus)


func _process(delta: float) -> void:
	match game_state:
		GameState.BUILD_PHASE:
			# Wave 1: no auto-start, player must click Start Wave
			if current_wave > 1:
				_build_timer -= delta
				if _build_timer <= 0.0:
					_transition_to(GameState.COMBAT_PHASE)
		GameState.COMBAT_PHASE:
			if EnemySystem.get_active_enemy_count() == 0 and EnemySystem.is_wave_finished():
				_on_wave_cleared()


func _transition_to(new_state: GameState) -> void:
	game_state = new_state
	match new_state:
		GameState.BUILD_PHASE:
			current_wave += 1
			_build_timer = build_phase_duration
		GameState.COMBAT_PHASE:
			_enemies_leaked_this_wave = 0
			wave_started.emit(current_wave)
			EnemySystem.spawn_wave(current_wave)
		GameState.INCOME_PHASE:
			EconomyManager.apply_interest()
			_transition_to(GameState.BUILD_PHASE)
		GameState.GAME_OVER:
			var victory: bool = current_wave >= max_waves
			game_over.emit(victory)
	phase_changed.emit(new_state)


func _on_wave_cleared() -> void:
	# Award wave clear bonus (with no-leak bonus if applicable)
	var bonus: int = EconomyManager.calculate_wave_bonus(current_wave, _enemies_leaked_this_wave)
	EconomyManager.add_gold(bonus)
	wave_completed.emit(current_wave)
	if current_wave >= max_waves:
		_transition_to(GameState.GAME_OVER)
	elif current_wave % 5 == 0:
		_transition_to(GameState.INCOME_PHASE)
	else:
		_transition_to(GameState.BUILD_PHASE)


func lose_life(amount: int = 1) -> void:
	lives -= amount
	if lives <= 0:
		lives = 0
		_transition_to(GameState.GAME_OVER)


func record_enemy_leak() -> void:
	_enemies_leaked_this_wave += 1
