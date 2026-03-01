extends GdUnitTestSuite

## Unit tests for Tower.gd sprite path resolution per tier.
## Covers: base tier sprite path, enhanced/superior suffix paths, fusion subdirectory,
## legendary subdirectory, fallback behavior when sprite is missing, and the
## get_sprite_path() static helper.


# -- Helpers -------------------------------------------------------------------

static var _tower_script: GDScript = null

func _make_tower_data(
	p_name: String = "Flame Spire",
	p_element: String = "fire",
	p_tier: int = 1,
	p_fusion_elements: Array[String] = []
) -> TowerData:
	var data := TowerData.new()
	data.tower_name = p_name
	data.element = p_element
	data.tier = p_tier
	data.damage = 10
	data.attack_speed = 1.0
	data.range_cells = 4
	data.damage_type = p_element
	data.fusion_elements = p_fusion_elements
	return data


func _load_tower_script() -> GDScript:
	if _tower_script == null:
		_tower_script = load("res://scripts/towers/Tower.gd") as GDScript
	return _tower_script


func after() -> void:
	_tower_script = null


# -- Tests: get_sprite_path() static helper ------------------------------------

func test_get_sprite_path_base_tower() -> void:
	var script: GDScript = _load_tower_script()
	var data := _make_tower_data("Flame Spire", "fire", 1)
	var path: String = script.get_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/flame_spire.png")


func test_get_sprite_path_enhanced_tower() -> void:
	var script: GDScript = _load_tower_script()
	var data := _make_tower_data("Flame Spire Enhanced", "fire", 1)
	var path: String = script.get_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/flame_spire_enhanced.png")


func test_get_sprite_path_superior_tower() -> void:
	var script: GDScript = _load_tower_script()
	var data := _make_tower_data("Flame Spire Superior", "fire", 1)
	var path: String = script.get_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/flame_spire_superior.png")


func test_get_sprite_path_fusion_tower() -> void:
	var script: GDScript = _load_tower_script()
	var fe: Array[String] = ["fire", "water"]
	var data := _make_tower_data("Steam Engine", "fire", 2, fe)
	var path: String = script.get_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/fusions/steam_engine.png")


func test_get_sprite_path_legendary_tower() -> void:
	var script: GDScript = _load_tower_script()
	var fe: Array[String] = ["earth", "fire", "wind"]
	var data := _make_tower_data("Volcanic Tempest", "fire", 3, fe)
	var path: String = script.get_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/legendaries/volcanic_tempest.png")


func test_get_sprite_path_handles_special_characters() -> void:
	# Cryo-Volt Array has a hyphen in the name
	var script: GDScript = _load_tower_script()
	var fe: Array[String] = ["ice", "lightning"]
	var data := _make_tower_data("Cryo-Volt Array", "ice", 2, fe)
	var path: String = script.get_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/fusions/cryo-volt_array.png")


# -- Tests: All 6 base towers resolve correctly --------------------------------

func test_get_sprite_path_all_base_towers() -> void:
	var script: GDScript = _load_tower_script()
	var bases: Array[Array] = [
		["Flame Spire", "fire"],
		["Frost Sentinel", "ice"],
		["Gale Tower", "wind"],
		["Stone Bastion", "earth"],
		["Thunder Pylon", "lightning"],
		["Tidal Obelisk", "water"],
	]
	for entry: Array in bases:
		var data := _make_tower_data(entry[0], entry[1], 1)
		var path: String = script.get_sprite_path(data)
		var expected_name: String = entry[0].to_lower().replace(" ", "_")
		assert_str(path).override_failure_message(
			"Base tower '%s' sprite path mismatch" % entry[0]
		).is_equal("res://assets/sprites/towers/%s.png" % expected_name)


# -- Tests: All 6 enhanced towers resolve correctly ----------------------------

func test_get_sprite_path_all_enhanced_towers() -> void:
	var script: GDScript = _load_tower_script()
	var towers: Array[Array] = [
		["Flame Spire Enhanced", "fire"],
		["Frost Sentinel Enhanced", "ice"],
		["Gale Tower Enhanced", "wind"],
		["Stone Bastion Enhanced", "earth"],
		["Thunder Pylon Enhanced", "lightning"],
		["Tidal Obelisk Enhanced", "water"],
	]
	for entry: Array in towers:
		var data := _make_tower_data(entry[0], entry[1], 1)
		var path: String = script.get_sprite_path(data)
		var expected_name: String = entry[0].to_lower().replace(" ", "_")
		assert_str(path).override_failure_message(
			"Enhanced tower '%s' sprite path mismatch" % entry[0]
		).is_equal("res://assets/sprites/towers/%s.png" % expected_name)


# -- Tests: All 6 superior towers resolve correctly ----------------------------

func test_get_sprite_path_all_superior_towers() -> void:
	var script: GDScript = _load_tower_script()
	var towers: Array[Array] = [
		["Flame Spire Superior", "fire"],
		["Frost Sentinel Superior", "ice"],
		["Gale Tower Superior", "wind"],
		["Stone Bastion Superior", "earth"],
		["Thunder Pylon Superior", "lightning"],
		["Tidal Obelisk Superior", "water"],
	]
	for entry: Array in towers:
		var data := _make_tower_data(entry[0], entry[1], 1)
		var path: String = script.get_sprite_path(data)
		var expected_name: String = entry[0].to_lower().replace(" ", "_")
		assert_str(path).override_failure_message(
			"Superior tower '%s' sprite path mismatch" % entry[0]
		).is_equal("res://assets/sprites/towers/%s.png" % expected_name)


# -- Tests: All 15 fusion towers resolve to fusions/ subdirectory --------------

func test_get_sprite_path_all_fusion_towers() -> void:
	var script: GDScript = _load_tower_script()
	var fusions: Array[Array] = [
		["Blizzard Tower", "ice", ["ice", "wind"]],
		["Cryo-Volt Array", "ice", ["ice", "lightning"]],
		["Glacier Keep", "ice", ["ice", "water"]],
		["Inferno Vortex", "fire", ["fire", "wind"]],
		["Magma Forge", "earth", ["earth", "fire"]],
		["Mud Pit", "earth", ["earth", "water"]],
		["Permafrost Pillar", "earth", ["earth", "ice"]],
		["Plasma Cannon", "fire", ["fire", "lightning"]],
		["Sandstorm Citadel", "earth", ["earth", "wind"]],
		["Seismic Coil", "earth", ["earth", "lightning"]],
		["Steam Engine", "fire", ["fire", "water"]],
		["Storm Beacon", "lightning", ["lightning", "water"]],
		["Tempest Spire", "lightning", ["lightning", "wind"]],
		["Thermal Shock", "fire", ["fire", "ice"]],
		["Tsunami Shrine", "water", ["water", "wind"]],
	]
	for entry: Array in fusions:
		var fe: Array[String] = []
		for e: String in entry[2]:
			fe.append(e)
		var data := _make_tower_data(entry[0], entry[1], 2, fe)
		var path: String = script.get_sprite_path(data)
		var expected_name: String = entry[0].to_lower().replace(" ", "_")
		assert_str(path).override_failure_message(
			"Fusion tower '%s' sprite path mismatch" % entry[0]
		).is_equal("res://assets/sprites/towers/fusions/%s.png" % expected_name)


# -- Tests: All 6 legendary towers resolve to legendaries/ subdirectory --------

func test_get_sprite_path_all_legendary_towers() -> void:
	var script: GDScript = _load_tower_script()
	var legendaries: Array[Array] = [
		["Arctic Maelstrom", "ice", ["ice", "water", "wind"]],
		["Crystalline Monolith", "earth", ["earth", "ice", "lightning"]],
		["Primordial Nexus", "earth", ["earth", "fire", "water"]],
		["Supercell Obelisk", "fire", ["fire", "lightning", "wind"]],
		["Tectonic Dynamo", "earth", ["earth", "lightning", "water"]],
		["Volcanic Tempest", "fire", ["earth", "fire", "wind"]],
	]
	for entry: Array in legendaries:
		var fe: Array[String] = []
		for e: String in entry[2]:
			fe.append(e)
		var data := _make_tower_data(entry[0], entry[1], 3, fe)
		var path: String = script.get_sprite_path(data)
		var expected_name: String = entry[0].to_lower().replace(" ", "_")
		assert_str(path).override_failure_message(
			"Legendary tower '%s' sprite path mismatch" % entry[0]
		).is_equal("res://assets/sprites/towers/legendaries/%s.png" % expected_name)


# -- Tests: Fallback behavior --------------------------------------------------

func test_get_fallback_sprite_path_base_tower() -> void:
	var script: GDScript = _load_tower_script()
	var data := _make_tower_data("Flame Spire", "fire", 1)
	var path: String = script.get_fallback_sprite_path(data)
	# Base towers fall back to the element-named sprite
	assert_str(path).is_equal("res://assets/sprites/towers/fire.png")


func test_get_fallback_sprite_path_enhanced_strips_suffix() -> void:
	var script: GDScript = _load_tower_script()
	var data := _make_tower_data("Flame Spire Enhanced", "fire", 1)
	var path: String = script.get_fallback_sprite_path(data)
	# Enhanced falls back to the base tower sprite (without suffix)
	assert_str(path).is_equal("res://assets/sprites/towers/flame_spire.png")


func test_get_fallback_sprite_path_superior_strips_suffix() -> void:
	var script: GDScript = _load_tower_script()
	var data := _make_tower_data("Frost Sentinel Superior", "ice", 1)
	var path: String = script.get_fallback_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/frost_sentinel.png")


func test_get_fallback_sprite_path_fusion_falls_back_to_base_dir() -> void:
	var script: GDScript = _load_tower_script()
	var fe: Array[String] = ["fire", "water"]
	var data := _make_tower_data("Steam Engine", "fire", 2, fe)
	var path: String = script.get_fallback_sprite_path(data)
	# Fusions fall back to element sprite in base towers dir
	assert_str(path).is_equal("res://assets/sprites/towers/fire.png")


func test_get_fallback_sprite_path_legendary_falls_back_to_base_dir() -> void:
	var script: GDScript = _load_tower_script()
	var fe: Array[String] = ["earth", "fire", "wind"]
	var data := _make_tower_data("Volcanic Tempest", "fire", 3, fe)
	var path: String = script.get_fallback_sprite_path(data)
	assert_str(path).is_equal("res://assets/sprites/towers/fire.png")


# -- Tests: Sprite file existence (generated assets) ---------------------------

func test_enhanced_sprites_exist() -> void:
	var bases: Array[String] = [
		"flame_spire", "frost_sentinel", "gale_tower",
		"stone_bastion", "thunder_pylon", "tidal_obelisk",
	]
	for base_name: String in bases:
		var path: String = "res://assets/sprites/towers/%s_enhanced.png" % base_name
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"Enhanced sprite missing: %s" % path
		).is_true()


func test_superior_sprites_exist() -> void:
	var bases: Array[String] = [
		"flame_spire", "frost_sentinel", "gale_tower",
		"stone_bastion", "thunder_pylon", "tidal_obelisk",
	]
	for base_name: String in bases:
		var path: String = "res://assets/sprites/towers/%s_superior.png" % base_name
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"Superior sprite missing: %s" % path
		).is_true()


func test_fusion_sprites_exist() -> void:
	var fusions: Array[String] = [
		"blizzard_tower", "cryo-volt_array", "glacier_keep",
		"inferno_vortex", "magma_forge", "mud_pit",
		"permafrost_pillar", "plasma_cannon", "sandstorm_citadel",
		"seismic_coil", "steam_engine", "storm_beacon",
		"tempest_spire", "thermal_shock", "tsunami_shrine",
	]
	for fusion_name: String in fusions:
		var path: String = "res://assets/sprites/towers/fusions/%s.png" % fusion_name
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"Fusion sprite missing: %s" % path
		).is_true()


func test_legendary_sprites_exist() -> void:
	var legendaries: Array[String] = [
		"arctic_maelstrom", "crystalline_monolith", "primordial_nexus",
		"supercell_obelisk", "tectonic_dynamo", "volcanic_tempest",
	]
	for legendary_name: String in legendaries:
		var path: String = "res://assets/sprites/towers/legendaries/%s.png" % legendary_name
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"Legendary sprite missing: %s" % path
		).is_true()


# -- Tests: Sprite dimensions --------------------------------------------------

func test_enhanced_sprites_are_64x64() -> void:
	var bases: Array[String] = [
		"flame_spire", "frost_sentinel", "gale_tower",
		"stone_bastion", "thunder_pylon", "tidal_obelisk",
	]
	for base_name: String in bases:
		var path: String = "res://assets/sprites/towers/%s_enhanced.png" % base_name
		var tex: Texture2D = load(path)
		if tex:
			assert_int(tex.get_width()).override_failure_message(
				"%s width should be 64" % base_name
			).is_equal(64)
			assert_int(tex.get_height()).override_failure_message(
				"%s height should be 64" % base_name
			).is_equal(64)


func test_fusion_sprites_are_64x64() -> void:
	var fusions: Array[String] = [
		"blizzard_tower", "cryo-volt_array", "glacier_keep",
		"inferno_vortex", "magma_forge", "mud_pit",
		"permafrost_pillar", "plasma_cannon", "sandstorm_citadel",
		"seismic_coil", "steam_engine", "storm_beacon",
		"tempest_spire", "thermal_shock", "tsunami_shrine",
	]
	for fusion_name: String in fusions:
		var path: String = "res://assets/sprites/towers/fusions/%s.png" % fusion_name
		var tex: Texture2D = load(path)
		if tex:
			assert_int(tex.get_width()).override_failure_message(
				"%s width should be 64" % fusion_name
			).is_equal(64)
			assert_int(tex.get_height()).override_failure_message(
				"%s height should be 64" % fusion_name
			).is_equal(64)


func test_legendary_sprites_are_64x64() -> void:
	var legendaries: Array[String] = [
		"arctic_maelstrom", "crystalline_monolith", "primordial_nexus",
		"supercell_obelisk", "tectonic_dynamo", "volcanic_tempest",
	]
	for legendary_name: String in legendaries:
		var path: String = "res://assets/sprites/towers/legendaries/%s.png" % legendary_name
		var tex: Texture2D = load(path)
		if tex:
			assert_int(tex.get_width()).override_failure_message(
				"%s width should be 64" % legendary_name
			).is_equal(64)
			assert_int(tex.get_height()).override_failure_message(
				"%s height should be 64" % legendary_name
			).is_equal(64)


# -- Tests: Total sprite count -------------------------------------------------

func test_total_new_sprite_count_is_33() -> void:
	# 12 enhanced/superior + 15 fusions + 6 legendaries = 33
	var count: int = 0
	# Enhanced (6)
	for base_name: String in ["flame_spire", "frost_sentinel", "gale_tower", "stone_bastion", "thunder_pylon", "tidal_obelisk"]:
		if ResourceLoader.exists("res://assets/sprites/towers/%s_enhanced.png" % base_name):
			count += 1
	# Superior (6)
	for base_name: String in ["flame_spire", "frost_sentinel", "gale_tower", "stone_bastion", "thunder_pylon", "tidal_obelisk"]:
		if ResourceLoader.exists("res://assets/sprites/towers/%s_superior.png" % base_name):
			count += 1
	# Fusions (15)
	for fusion_name: String in ["blizzard_tower", "cryo-volt_array", "glacier_keep", "inferno_vortex", "magma_forge", "mud_pit", "permafrost_pillar", "plasma_cannon", "sandstorm_citadel", "seismic_coil", "steam_engine", "storm_beacon", "tempest_spire", "thermal_shock", "tsunami_shrine"]:
		if ResourceLoader.exists("res://assets/sprites/towers/fusions/%s.png" % fusion_name):
			count += 1
	# Legendaries (6)
	for legendary_name: String in ["arctic_maelstrom", "crystalline_monolith", "primordial_nexus", "supercell_obelisk", "tectonic_dynamo", "volcanic_tempest"]:
		if ResourceLoader.exists("res://assets/sprites/towers/legendaries/%s.png" % legendary_name):
			count += 1
	assert_int(count).is_equal(33)
