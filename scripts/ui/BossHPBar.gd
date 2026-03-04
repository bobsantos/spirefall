extends PanelContainer

## Full-width boss HP bar displayed below the HUD TopBar during boss waves.
## Shows boss name, element-colored HP bar, and current/max HP text.
## Shown when a boss spawns, hidden when the boss dies or the wave ends.

@onready var boss_name_label: Label = $HBoxContainer/BossNameLabel
@onready var hp_bar: ProgressBar = $HBoxContainer/HPBar
@onready var hp_text: Label = $HBoxContainer/HPText

var _tracked_boss: Node = null


func _ready() -> void:
	visible = false


func show_for_boss(enemy: Node) -> void:
	## Show the HP bar for the given boss enemy. Ignores non-boss enemies.
	if not enemy or not enemy.enemy_data or not enemy.enemy_data.is_boss:
		return

	_tracked_boss = enemy
	var data: EnemyData = enemy.enemy_data

	# Boss name with element color
	boss_name_label.text = data.enemy_name
	var element_color: Color = ElementMatrix.get_color(data.element)
	boss_name_label.add_theme_color_override("font_color", element_color)

	# HP bar max/value
	hp_bar.max_value = enemy.max_health
	hp_bar.value = enemy.current_health

	# Element-colored fill
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = element_color
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("fill", fill_style)

	# HP text
	hp_text.text = "%d/%d" % [enemy.current_health, enemy.max_health]

	visible = true


func update_hp() -> void:
	## Update the HP bar and text from the tracked boss's current health.
	## Hides the bar if the boss reference is no longer valid.
	if _tracked_boss == null:
		return
	if not is_instance_valid(_tracked_boss):
		hide_bar()
		return

	hp_bar.max_value = _tracked_boss.max_health
	hp_bar.value = _tracked_boss.current_health
	hp_text.text = "%d/%d" % [_tracked_boss.current_health, _tracked_boss.max_health]


func hide_bar() -> void:
	## Hide the HP bar and clear the tracked boss reference.
	visible = false
	_tracked_boss = null


func on_enemy_spawned(enemy: Node) -> void:
	## Called when any enemy spawns. Only shows bar for boss enemies.
	if enemy and enemy.enemy_data and enemy.enemy_data.is_boss:
		show_for_boss(enemy)


func on_enemy_killed(enemy: Node) -> void:
	## Called when any enemy dies. Hides bar if it was the tracked boss.
	if enemy == _tracked_boss:
		hide_bar()


func on_wave_cleared(_wave_number: int) -> void:
	## Called when a wave ends. Always hides the boss bar.
	hide_bar()


func _process(_delta: float) -> void:
	if visible and _tracked_boss != null:
		update_hp()
