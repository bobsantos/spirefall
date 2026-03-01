extends GdUnitTestSuite

## Tests for Task I6: Enemy Sprites Per Type.
## Validates that all enemy types have distinct sprite files at the expected paths,
## that dimensions are 64x64, and that special sprites (stealth, elemental, boss)
## meet their visual requirements.

const SPRITE_DIR: String = "res://assets/sprites/enemies/"

# All enemy types and their expected sprite filenames.
# Derived from EnemyData.enemy_name.to_lower().replace(" ", "_") + ".png"
const EXPECTED_SPRITES: Array[String] = [
	"normal.png",
	"fast.png",
	"armored.png",
	"flying.png",
	"swarm.png",
	"healer.png",
	"split.png",
	"stealth.png",
	"elemental.png",
	"ember_titan.png",
	"glacial_wyrm.png",
	"chaos_elemental.png",
	"split_child.png",
	"ice_minion.png",
]

const BOSS_SPRITES: Array[String] = [
	"ember_titan.png",
	"glacial_wyrm.png",
	"chaos_elemental.png",
]


# ==============================================================================
# SECTION 1: Sprite File Existence
# ==============================================================================

# -- 1. All expected sprite files exist ----------------------------------------

func test_all_sprite_files_exist() -> void:
	for sprite_name: String in EXPECTED_SPRITES:
		var path: String = SPRITE_DIR + sprite_name
		var exists: bool = ResourceLoader.exists(path)
		assert_bool(exists).override_failure_message(
			"Missing sprite file: %s" % path
		).is_true()


# -- 2. Normal enemy sprite exists ---------------------------------------------

func test_normal_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "normal.png")).is_true()


# -- 3. Fast enemy sprite exists -----------------------------------------------

func test_fast_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "fast.png")).is_true()


# -- 4. Armored enemy sprite exists --------------------------------------------

func test_armored_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "armored.png")).is_true()


# -- 5. Flying enemy sprite exists ---------------------------------------------

func test_flying_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "flying.png")).is_true()


# -- 6. Swarm enemy sprite exists ----------------------------------------------

func test_swarm_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "swarm.png")).is_true()


# -- 7. Healer enemy sprite exists ---------------------------------------------

func test_healer_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "healer.png")).is_true()


# -- 8. Split enemy sprite exists ----------------------------------------------

func test_split_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "split.png")).is_true()


# -- 9. Stealth enemy sprite exists --------------------------------------------

func test_stealth_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "stealth.png")).is_true()


# -- 10. Elemental enemy sprite exists -----------------------------------------

func test_elemental_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "elemental.png")).is_true()


# -- 11. Split child sprite exists ---------------------------------------------

func test_split_child_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "split_child.png")).is_true()


# -- 12. Ice minion sprite exists ----------------------------------------------

func test_ice_minion_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "ice_minion.png")).is_true()


# ==============================================================================
# SECTION 2: Boss Sprite Existence
# ==============================================================================

# -- 13. Ember Titan boss sprite exists ----------------------------------------

func test_boss_ember_titan_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "ember_titan.png")).is_true()


# -- 14. Glacial Wyrm boss sprite exists ---------------------------------------

func test_boss_glacial_wyrm_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "glacial_wyrm.png")).is_true()


# -- 15. Chaos Elemental boss sprite exists ------------------------------------

func test_boss_chaos_elemental_sprite_exists() -> void:
	assert_bool(ResourceLoader.exists(SPRITE_DIR + "chaos_elemental.png")).is_true()


# ==============================================================================
# SECTION 3: Sprite Dimensions (64x64)
# ==============================================================================

# -- 16. All sprites are 64x64 ------------------------------------------------

func test_all_sprites_are_64x64() -> void:
	for sprite_name: String in EXPECTED_SPRITES:
		var path: String = SPRITE_DIR + sprite_name
		var tex: Texture2D = load(path)
		assert_bool(tex != null).override_failure_message(
			"Could not load texture: %s" % path
		).is_true()
		if tex:
			var img: Image = tex.get_image()
			assert_int(img.get_width()).override_failure_message(
				"%s width should be 64, got %d" % [sprite_name, img.get_width()]
			).is_equal(64)
			assert_int(img.get_height()).override_failure_message(
				"%s height should be 64, got %d" % [sprite_name, img.get_height()]
			).is_equal(64)


# -- 17. Boss sprites are also 64x64 (scaling is done at runtime) -------------

func test_boss_sprites_are_64x64() -> void:
	for sprite_name: String in BOSS_SPRITES:
		var path: String = SPRITE_DIR + sprite_name
		var tex: Texture2D = load(path)
		assert_bool(tex != null).override_failure_message(
			"Could not load boss texture: %s" % path
		).is_true()
		if tex:
			var img: Image = tex.get_image()
			assert_int(img.get_width()).is_equal(64)
			assert_int(img.get_height()).is_equal(64)


# ==============================================================================
# SECTION 4: Sprite Loading via _apply_enemy_data() Path Convention
# ==============================================================================

# -- 18. enemy_name to sprite path conversion is correct -----------------------

func test_name_to_path_conversion() -> void:
	# Verify the snake_case conversion produces correct paths for all .tres files
	var test_cases: Dictionary = {
		"Normal": "normal.png",
		"Fast": "fast.png",
		"Armored": "armored.png",
		"Flying": "flying.png",
		"Swarm": "swarm.png",
		"Healer": "healer.png",
		"Split": "split.png",
		"Stealth": "stealth.png",
		"Elemental": "elemental.png",
		"Ember Titan": "ember_titan.png",
		"Glacial Wyrm": "glacial_wyrm.png",
		"Chaos Elemental": "chaos_elemental.png",
		"Split Child": "split_child.png",
		"Ice Minion": "ice_minion.png",
	}

	for enemy_name: String in test_cases:
		var expected_file: String = test_cases[enemy_name]
		var texture_name: String = enemy_name.to_lower().replace(" ", "_")
		var computed_path: String = SPRITE_DIR + texture_name + ".png"
		var expected_path: String = SPRITE_DIR + expected_file
		assert_str(computed_path).override_failure_message(
			"Path mismatch for '%s': expected %s got %s" % [enemy_name, expected_path, computed_path]
		).is_equal(expected_path)


# -- 19. All .tres enemy_name fields resolve to existing sprites ---------------

func test_all_tres_names_resolve_to_sprites() -> void:
	var enemy_types: Array[String] = [
		"normal", "fast", "armored", "flying", "swarm",
		"healer", "split", "stealth", "elemental",
		"boss_ember_titan", "boss_glacial_wyrm", "boss_chaos_elemental",
		"split_child", "ice_minion",
	]
	for enemy_type: String in enemy_types:
		var tres_path: String = "res://resources/enemies/%s.tres" % enemy_type
		var data: EnemyData = load(tres_path)
		assert_bool(data != null).override_failure_message(
			"Could not load resource: %s" % tres_path
		).is_true()
		if data:
			var texture_name: String = data.enemy_name.to_lower().replace(" ", "_")
			var texture_path: String = SPRITE_DIR + texture_name + ".png"
			assert_bool(ResourceLoader.exists(texture_path)).override_failure_message(
				"No sprite for '%s' (enemy_name='%s'): expected %s" % [enemy_type, data.enemy_name, texture_path]
			).is_true()


# ==============================================================================
# SECTION 5: Stealth Sprite Opacity
# ==============================================================================

# -- 20. Stealth sprite is fully opaque in the file ----------------------------

func test_stealth_sprite_fully_opaque() -> void:
	var tex: Texture2D = load(SPRITE_DIR + "stealth.png")
	assert_bool(tex != null).is_true()
	var img: Image = tex.get_image()
	# Check that all non-transparent pixels have alpha = 255 (fully opaque).
	# The shape may have transparent background pixels, but the shape itself must be opaque.
	var has_opaque_pixel: bool = false
	var has_semi_transparent_shape_pixel: bool = false
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var pixel: Color = img.get_pixel(x, y)
			if pixel.a > 0.0 and pixel.a < 1.0:
				has_semi_transparent_shape_pixel = true
			if pixel.a == 1.0:
				has_opaque_pixel = true
	assert_bool(has_opaque_pixel).override_failure_message(
		"Stealth sprite has no fully opaque pixels"
	).is_true()
	assert_bool(has_semi_transparent_shape_pixel).override_failure_message(
		"Stealth sprite has semi-transparent pixels (runtime handles transparency)"
	).is_false()


# ==============================================================================
# SECTION 6: Elemental Sprite Neutrality
# ==============================================================================

# -- 21. Elemental sprite is white/neutral for runtime tinting -----------------

func test_elemental_sprite_is_neutral() -> void:
	var tex: Texture2D = load(SPRITE_DIR + "elemental.png")
	assert_bool(tex != null).is_true()
	var img: Image = tex.get_image()
	# All visible pixels should be white/light gray (high value, low saturation)
	# so that runtime element tinting via modulate works correctly.
	var total_pixels: int = 0
	var neutral_pixels: int = 0
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var pixel: Color = img.get_pixel(x, y)
			if pixel.a < 0.5:
				continue  # Skip transparent background
			total_pixels += 1
			# Neutral = low saturation (r ~= g ~= b) and brightness >= 0.7
			var min_c: float = minf(pixel.r, minf(pixel.g, pixel.b))
			var max_c: float = maxf(pixel.r, maxf(pixel.g, pixel.b))
			var saturation: float = max_c - min_c
			if saturation < 0.15 and max_c >= 0.7:
				neutral_pixels += 1
	assert_bool(total_pixels > 0).override_failure_message(
		"Elemental sprite has no visible pixels"
	).is_true()
	# At least 90% of visible pixels should be neutral white/gray
	var ratio: float = float(neutral_pixels) / float(total_pixels) if total_pixels > 0 else 0.0
	assert_bool(ratio >= 0.9).override_failure_message(
		"Elemental sprite is not neutral enough for tinting: %.1f%% neutral (need 90%%)" % [ratio * 100.0]
	).is_true()


# ==============================================================================
# SECTION 7: Visual Distinctness
# ==============================================================================

# -- 22. Each sprite has non-empty content (not blank) -------------------------

func test_sprites_have_content() -> void:
	for sprite_name: String in EXPECTED_SPRITES:
		var path: String = SPRITE_DIR + sprite_name
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		var has_visible_pixel: bool = false
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.0:
					has_visible_pixel = true
					break
			if has_visible_pixel:
				break
		assert_bool(has_visible_pixel).override_failure_message(
			"Sprite %s is completely blank (no visible pixels)" % sprite_name
		).is_true()


# -- 23. No two sprites are identical -----------------------------------------

func test_no_duplicate_sprites() -> void:
	# Compute a simple hash for each sprite (sum of all pixel RGBA values)
	# to verify no two sprites are identical.
	var hashes: Dictionary = {}  # hash_value -> sprite_name
	for sprite_name: String in EXPECTED_SPRITES:
		var path: String = SPRITE_DIR + sprite_name
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		var hash_val: int = 0
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				var pixel: Color = img.get_pixel(x, y)
				hash_val += int(pixel.r * 255) + int(pixel.g * 255) * 3 + int(pixel.b * 255) * 7 + int(pixel.a * 255) * 13
				hash_val = hash_val % 999999937  # Large prime to avoid overflow
		if hashes.has(hash_val):
			assert_bool(false).override_failure_message(
				"Sprites are identical: %s and %s" % [sprite_name, hashes[hash_val]]
			).is_true()
		hashes[hash_val] = sprite_name


# -- 24. Boss sprites have larger filled area than normal sprite ---------------

func test_boss_sprites_larger_than_normal() -> void:
	var normal_tex: Texture2D = load(SPRITE_DIR + "normal.png")
	if normal_tex == null:
		return
	var normal_pixels: int = _count_visible_pixels(normal_tex.get_image())

	for boss_name: String in BOSS_SPRITES:
		var tex: Texture2D = load(SPRITE_DIR + boss_name)
		if tex == null:
			continue
		var boss_pixels: int = _count_visible_pixels(tex.get_image())
		assert_bool(boss_pixels > normal_pixels).override_failure_message(
			"Boss sprite %s (%d visible px) should have more filled area than normal (%d px)" % [boss_name, boss_pixels, normal_pixels]
		).is_true()


func _count_visible_pixels(img: Image) -> int:
	var count: int = 0
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				count += 1
	return count
