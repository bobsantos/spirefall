extends Control

## Full-screen boss announcement splash shown briefly when a boss wave starts.
## Slides in from top, holds, then fades out. Does NOT pause the game.

@onready var overlay: ColorRect = $Overlay
@onready var boss_name_label: Label = $CenterContainer/VBoxContainer/BossNameLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel

const TOTAL_DURATION: float = 2.0
const HOLD_DURATION: float = 1.5
const FADE_DURATION: float = 0.5

const BOSS_SUBTITLES: Dictionary = {
	"Ember Titan": "Leaves a trail of fire in its wake",
	"Glacial Wyrm": "Freezes towers caught in its gaze",
	"Chaos Elemental": "Shifts between elemental forms",
}

var _anim_tween: Tween = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_announcement(boss_name: String, element: String, subtitle: String) -> void:
	## Display the boss announcement with the given name, element color, and subtitle.
	boss_name_label.text = boss_name
	subtitle_label.text = subtitle

	# Apply element color to boss name
	var element_color: Color = ElementMatrix.get_color(element)
	boss_name_label.add_theme_color_override("font_color", element_color)

	# Reset modulate for animation
	modulate = Color(1, 1, 1, 1)
	visible = true

	# Animate: slide in, hold, fade out
	_start_animation()


func show_for_wave(_wave_number: int, is_boss_wave: bool, boss_name: String, element: String) -> void:
	## Called by HUD when a wave starts. Only shows for boss waves.
	if not is_boss_wave:
		return

	var subtitle: String = BOSS_SUBTITLES.get(boss_name, "A powerful foe approaches")
	show_announcement(boss_name, element, subtitle)


func on_wave_started(wave_number: int) -> void:
	## Signal handler for GameManager.wave_started.
	## Checks wave config to determine if this is a boss wave.
	var wave_config: Dictionary = EnemySystem.get_wave_config(wave_number)
	var is_boss: bool = wave_config.get("is_boss_wave", false)
	if not is_boss:
		return

	# Extract boss info from wave config enemies array
	var boss_name: String = ""
	var element: String = "none"
	var enemies: Array = wave_config.get("enemies", [])
	for group: Dictionary in enemies:
		var enemy_type: String = group.get("type", "")
		var template: EnemyData = EnemySystem.get_enemy_template(enemy_type)
		if template and template.is_boss:
			boss_name = template.enemy_name
			element = template.element
			break

	if boss_name != "":
		var subtitle: String = BOSS_SUBTITLES.get(boss_name, "A powerful foe approaches")
		show_announcement(boss_name, element, subtitle)


func dismiss() -> void:
	## Immediately hide the announcement.
	visible = false
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null


func _start_animation() -> void:
	## Slide in from top, hold, then fade out.
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	if not is_inside_tree():
		return

	_anim_tween = create_tween()

	# Slide in: start offset above, animate to center
	var start_offset: float = -80.0
	position.y = start_offset
	_anim_tween.tween_property(self, "position:y", 0.0, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Hold for remaining time before fade
	_anim_tween.tween_interval(HOLD_DURATION - 0.3)

	# Fade out
	_anim_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)

	# Hide after animation completes
	_anim_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		position.y = 0.0
	)
