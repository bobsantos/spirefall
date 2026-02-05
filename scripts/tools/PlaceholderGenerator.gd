@tool
extends EditorScript

## Run this in the Godot editor (Script > Run) to generate placeholder sprites.
## Creates 64x64 colored PNGs for all tower and enemy types.

const SIZE: int = 64

var TOWER_COLORS: Dictionary = {
	"flame_spire": Color(0.9, 0.2, 0.1),       # Red
	"tidal_obelisk": Color(0.1, 0.4, 0.9),     # Blue
	"stone_bastion": Color(0.55, 0.4, 0.25),   # Brown
	"gale_tower": Color(0.85, 0.95, 0.85),     # Light green/white
	"thunder_pylon": Color(0.9, 0.85, 0.1),    # Yellow
	"frost_sentinel": Color(0.7, 0.85, 1.0),   # Light blue
}

var ENEMY_COLORS: Dictionary = {
	"normal": Color(0.6, 0.6, 0.6),            # Gray
	"fast": Color(0.2, 0.9, 0.2),              # Green
	"armored": Color(0.4, 0.4, 0.5),           # Dark gray
	"flying": Color(0.8, 0.8, 1.0),            # Light purple
	"swarm": Color(0.7, 0.7, 0.3),             # Yellow-green
	"boss_ember_titan": Color(0.95, 0.1, 0.05),# Bright red
}

var TILE_COLORS: Dictionary = {
	"path": Color(0.75, 0.7, 0.55),            # Sandy
	"buildable": Color(0.3, 0.55, 0.25),       # Grass green
	"unbuildable": Color(0.25, 0.2, 0.15),     # Dark brown
	"spawn": Color(0.9, 0.1, 0.9),             # Magenta
	"exit": Color(0.1, 0.9, 0.9),              # Cyan
}


func _run() -> void:
	_generate_set("res://assets/sprites/towers/", TOWER_COLORS, _draw_tower)
	_generate_set("res://assets/sprites/enemies/", ENEMY_COLORS, _draw_enemy)
	_generate_set("res://assets/sprites/tiles/", TILE_COLORS, _draw_tile)
	_generate_projectile_sprites()
	print("Placeholder sprites generated!")


func _generate_set(base_path: String, colors: Dictionary, draw_func: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(base_path)
	for key: String in colors:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		draw_func.call(img, colors[key])
		img.save_png(base_path + key + ".png")


func _draw_tower(img: Image, color: Color) -> void:
	# Diamond/spire shape
	var center: int = SIZE / 2
	for x: int in range(SIZE):
		for y: int in range(SIZE):
			var dx: float = absf(x - center)
			var dy: float = absf(y - center)
			if dx / (SIZE * 0.35) + dy / (SIZE * 0.45) <= 1.0:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _draw_enemy(img: Image, color: Color) -> void:
	# Circle shape
	var center: int = SIZE / 2
	var radius: float = SIZE * 0.4
	for x: int in range(SIZE):
		for y: int in range(SIZE):
			var dist: float = Vector2(x, y).distance_to(Vector2(center, center))
			if dist <= radius:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _draw_tile(img: Image, color: Color) -> void:
	# Filled square with slight border
	for x: int in range(SIZE):
		for y: int in range(SIZE):
			if x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1:
				img.set_pixel(x, y, color.darkened(0.3))
			else:
				img.set_pixel(x, y, color)


func _generate_projectile_sprites() -> void:
	var proj_path := "res://assets/sprites/projectiles/"
	DirAccess.make_dir_recursive_absolute(proj_path)
	var proj_colors: Dictionary = {
		"fire": Color(1.0, 0.4, 0.1),
		"water": Color(0.2, 0.5, 1.0),
		"earth": Color(0.6, 0.45, 0.2),
		"wind": Color(0.8, 1.0, 0.8),
		"lightning": Color(1.0, 1.0, 0.3),
		"ice": Color(0.7, 0.9, 1.0),
	}
	for key: String in proj_colors:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var center: int = 8
		for x: int in range(16):
			for y: int in range(16):
				if Vector2(x, y).distance_to(Vector2(center, center)) <= 6.0:
					img.set_pixel(x, y, proj_colors[key])
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		img.save_png(proj_path + key + ".png")
