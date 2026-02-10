extends GdUnitTestSuite

## Data Resource Validation Tests (Task 15).
## Validates all .tres files in resources/ load correctly and have consistent data.
## Catches data entry errors (missing upgrade chains, wrong tiers, missing fields) early.


# -- Tower resource paths (res:// format for load()) --------------------------------

const BASE_TOWER_PATHS: Array[String] = [
	"res://resources/towers/flame_spire.tres",
	"res://resources/towers/frost_sentinel.tres",
	"res://resources/towers/stone_bastion.tres",
	"res://resources/towers/thunder_pylon.tres",
	"res://resources/towers/tidal_obelisk.tres",
	"res://resources/towers/gale_tower.tres",
]

const ENHANCED_TOWER_PATHS: Array[String] = [
	"res://resources/towers/flame_spire_enhanced.tres",
	"res://resources/towers/frost_sentinel_enhanced.tres",
	"res://resources/towers/stone_bastion_enhanced.tres",
	"res://resources/towers/thunder_pylon_enhanced.tres",
	"res://resources/towers/tidal_obelisk_enhanced.tres",
	"res://resources/towers/gale_tower_enhanced.tres",
]

const SUPERIOR_TOWER_PATHS: Array[String] = [
	"res://resources/towers/flame_spire_superior.tres",
	"res://resources/towers/frost_sentinel_superior.tres",
	"res://resources/towers/stone_bastion_superior.tres",
	"res://resources/towers/thunder_pylon_superior.tres",
	"res://resources/towers/tidal_obelisk_superior.tres",
	"res://resources/towers/gale_tower_superior.tres",
]

const FUSION_TOWER_PATHS: Array[String] = [
	"res://resources/towers/fusions/blizzard_tower.tres",
	"res://resources/towers/fusions/cryo_volt_array.tres",
	"res://resources/towers/fusions/glacier_keep.tres",
	"res://resources/towers/fusions/inferno_vortex.tres",
	"res://resources/towers/fusions/magma_forge.tres",
	"res://resources/towers/fusions/mud_pit.tres",
	"res://resources/towers/fusions/permafrost_pillar.tres",
	"res://resources/towers/fusions/plasma_cannon.tres",
	"res://resources/towers/fusions/sandstorm_citadel.tres",
	"res://resources/towers/fusions/seismic_coil.tres",
	"res://resources/towers/fusions/steam_engine.tres",
	"res://resources/towers/fusions/storm_beacon.tres",
	"res://resources/towers/fusions/tempest_spire.tres",
	"res://resources/towers/fusions/thermal_shock.tres",
	"res://resources/towers/fusions/tsunami_shrine.tres",
]

const LEGENDARY_TOWER_PATHS: Array[String] = [
	"res://resources/towers/legendaries/arctic_maelstrom.tres",
	"res://resources/towers/legendaries/crystalline_monolith.tres",
	"res://resources/towers/legendaries/primordial_nexus.tres",
	"res://resources/towers/legendaries/supercell_obelisk.tres",
	"res://resources/towers/legendaries/tectonic_dynamo.tres",
	"res://resources/towers/legendaries/volcanic_tempest.tres",
]

# -- Enemy resource paths -----------------------------------------------------------

const ENEMY_PATHS: Array[String] = [
	"res://resources/enemies/normal.tres",
	"res://resources/enemies/fast.tres",
	"res://resources/enemies/armored.tres",
	"res://resources/enemies/swarm.tres",
	"res://resources/enemies/flying.tres",
	"res://resources/enemies/healer.tres",
	"res://resources/enemies/stealth.tres",
	"res://resources/enemies/split.tres",
	"res://resources/enemies/split_child.tres",
	"res://resources/enemies/elemental.tres",
	"res://resources/enemies/boss_ember_titan.tres",
	"res://resources/enemies/boss_glacial_wyrm.tres",
	"res://resources/enemies/boss_chaos_elemental.tres",
	"res://resources/enemies/ice_minion.tres",
]

const BOSS_PATHS: Array[String] = [
	"res://resources/enemies/boss_ember_titan.tres",
	"res://resources/enemies/boss_glacial_wyrm.tres",
	"res://resources/enemies/boss_chaos_elemental.tres",
]

const WAVE_CONFIG_PATH: String = "res://resources/waves/wave_config.json"


# -- Helper: load wave config JSON --------------------------------------------------

func _load_wave_config() -> Dictionary:
	var file := FileAccess.open(WAVE_CONFIG_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var json_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	return parsed as Dictionary


# ====================================================================================
# TOWER LOADING TESTS
# ====================================================================================

func test_all_6_base_tower_tres_load() -> void:
	assert_int(BASE_TOWER_PATHS.size()).is_equal(6)
	for path in BASE_TOWER_PATHS:
		var res: TowerData = load(path) as TowerData
		assert_object(res)\
			.override_failure_message("Failed to load base tower: %s" % path)\
			.is_not_null()
		assert_str(res.tower_name)\
			.override_failure_message("Base tower has empty name: %s" % path)\
			.is_not_empty()
		assert_int(res.tier)\
			.override_failure_message("Base tower tier != 1: %s" % path)\
			.is_equal(1)


func test_all_12_enhanced_superior_load() -> void:
	var all_paths: Array[String] = []
	all_paths.append_array(ENHANCED_TOWER_PATHS)
	all_paths.append_array(SUPERIOR_TOWER_PATHS)
	assert_int(all_paths.size()).is_equal(12)
	for path in all_paths:
		var res: TowerData = load(path) as TowerData
		assert_object(res)\
			.override_failure_message("Failed to load enhanced/superior tower: %s" % path)\
			.is_not_null()
		assert_str(res.tower_name)\
			.override_failure_message("Enhanced/Superior tower has empty name: %s" % path)\
			.is_not_empty()
		assert_int(res.tier)\
			.override_failure_message("Enhanced/Superior tower tier != 1: %s" % path)\
			.is_equal(1)


func test_all_15_fusion_tres_load() -> void:
	assert_int(FUSION_TOWER_PATHS.size()).is_equal(15)
	for path in FUSION_TOWER_PATHS:
		var res: TowerData = load(path) as TowerData
		assert_object(res)\
			.override_failure_message("Failed to load fusion tower: %s" % path)\
			.is_not_null()
		assert_int(res.tier)\
			.override_failure_message("Fusion tower tier != 2: %s" % path)\
			.is_equal(2)


func test_all_6_legendary_tres_load() -> void:
	assert_int(LEGENDARY_TOWER_PATHS.size()).is_equal(6)
	for path in LEGENDARY_TOWER_PATHS:
		var res: TowerData = load(path) as TowerData
		assert_object(res)\
			.override_failure_message("Failed to load legendary tower: %s" % path)\
			.is_not_null()
		assert_int(res.tier)\
			.override_failure_message("Legendary tower tier != 3: %s" % path)\
			.is_equal(3)


# ====================================================================================
# TOWER UPGRADE CHAIN TESTS
# ====================================================================================

func test_base_towers_have_upgrade_chain() -> void:
	# Base -> Enhanced -> Superior: each base must have upgrade_to pointing to enhanced,
	# and each enhanced must have upgrade_to pointing to superior.
	for i in range(BASE_TOWER_PATHS.size()):
		var base: TowerData = load(BASE_TOWER_PATHS[i]) as TowerData
		assert_object(base.upgrade_to)\
			.override_failure_message("Base tower has no upgrade_to: %s" % BASE_TOWER_PATHS[i])\
			.is_not_null()

		var enhanced: TowerData = base.upgrade_to
		assert_str(enhanced.tower_name)\
			.override_failure_message("Enhanced tower has empty name (from base: %s)" % BASE_TOWER_PATHS[i])\
			.is_not_empty()
		assert_object(enhanced.upgrade_to)\
			.override_failure_message("Enhanced tower has no upgrade_to: %s" % enhanced.tower_name)\
			.is_not_null()

		var superior: TowerData = enhanced.upgrade_to
		assert_str(superior.tower_name)\
			.override_failure_message("Superior tower has empty name (from enhanced: %s)" % enhanced.tower_name)\
			.is_not_empty()


func test_superior_towers_have_no_upgrade() -> void:
	for path in SUPERIOR_TOWER_PATHS:
		var res: TowerData = load(path) as TowerData
		assert_object(res.upgrade_to)\
			.override_failure_message("Superior tower should have no upgrade_to: %s" % path)\
			.is_null()


# ====================================================================================
# TOWER FUSION ELEMENT TESTS
# ====================================================================================

func test_fusion_towers_have_fusion_elements() -> void:
	for path in FUSION_TOWER_PATHS:
		var res: TowerData = load(path) as TowerData
		assert_int(res.fusion_elements.size())\
			.override_failure_message("Fusion tower should have 2 fusion_elements: %s" % path)\
			.is_equal(2)


func test_legendary_towers_have_fusion_elements() -> void:
	for path in LEGENDARY_TOWER_PATHS:
		var res: TowerData = load(path) as TowerData
		assert_int(res.fusion_elements.size())\
			.override_failure_message("Legendary tower should have 3 fusion_elements: %s" % path)\
			.is_equal(3)


# ====================================================================================
# ENEMY LOADING TESTS
# ====================================================================================

func test_all_enemy_tres_load() -> void:
	assert_int(ENEMY_PATHS.size()).is_equal(14)
	for path in ENEMY_PATHS:
		var res: EnemyData = load(path) as EnemyData
		assert_object(res)\
			.override_failure_message("Failed to load enemy: %s" % path)\
			.is_not_null()
		assert_str(res.enemy_name)\
			.override_failure_message("Enemy has empty name: %s" % path)\
			.is_not_empty()


func test_boss_enemies_have_abilities() -> void:
	for path in BOSS_PATHS:
		var res: EnemyData = load(path) as EnemyData
		assert_bool(res.is_boss)\
			.override_failure_message("Boss enemy is_boss should be true: %s" % path)\
			.is_true()
		assert_str(res.boss_ability_key)\
			.override_failure_message("Boss enemy has empty boss_ability_key: %s" % path)\
			.is_not_empty()
		assert_float(res.boss_ability_interval)\
			.override_failure_message("Boss ability_interval should be > 0: %s" % path)\
			.is_greater(0.0)


func test_split_enemy_has_split_data() -> void:
	var split: EnemyData = load("res://resources/enemies/split.tres") as EnemyData
	assert_object(split).is_not_null()
	assert_bool(split.split_on_death).is_true()
	assert_object(split.split_data)\
		.override_failure_message("split.tres must have split_data pointing to split_child")\
		.is_not_null()
	assert_str(split.split_data.enemy_name).is_equal("Split Child")


func test_healer_has_heal_per_second() -> void:
	var healer: EnemyData = load("res://resources/enemies/healer.tres") as EnemyData
	assert_object(healer).is_not_null()
	assert_float(healer.heal_per_second)\
		.override_failure_message("healer.tres heal_per_second must be > 0")\
		.is_greater(0.0)


func test_flying_enemy_is_flying() -> void:
	var flying: EnemyData = load("res://resources/enemies/flying.tres") as EnemyData
	assert_object(flying).is_not_null()
	assert_bool(flying.is_flying).is_true()


func test_stealth_enemy_is_stealth() -> void:
	var stealth: EnemyData = load("res://resources/enemies/stealth.tres") as EnemyData
	assert_object(stealth).is_not_null()
	assert_bool(stealth.stealth).is_true()


# ====================================================================================
# WAVE CONFIG TESTS
# ====================================================================================

func test_wave_config_has_30_waves() -> void:
	var config: Dictionary = _load_wave_config()
	var waves: Array = config["waves"]
	assert_int(waves.size()).is_equal(30)
	# Verify wave numbers are sequential 1-30
	for i in range(30):
		var wave: Dictionary = waves[i]
		assert_int(int(wave["wave"]))\
			.override_failure_message("Wave at index %d should be wave %d" % [i, i + 1])\
			.is_equal(i + 1)


func test_wave_config_boss_waves() -> void:
	var config: Dictionary = _load_wave_config()
	var waves: Array = config["waves"]
	var boss_wave_numbers: Array[int] = [10, 20, 30]
	for wave_data: Dictionary in waves:
		var wave_num: int = int(wave_data["wave"])
		if wave_num in boss_wave_numbers:
			assert_bool(wave_data.get("is_boss_wave", false))\
				.override_failure_message("Wave %d should have is_boss_wave == true" % wave_num)\
				.is_true()


func test_wave_config_all_enemy_types_exist() -> void:
	var config: Dictionary = _load_wave_config()
	var waves: Array = config["waves"]
	# Collect all enemy types referenced in wave config
	var referenced_types: Dictionary = {}
	for wave_data: Dictionary in waves:
		var enemies: Array = wave_data["enemies"]
		for entry: Dictionary in enemies:
			referenced_types[entry["type"]] = true
	# Verify each type has a corresponding .tres file
	for enemy_type: String in referenced_types.keys():
		var path: String = "res://resources/enemies/%s.tres" % enemy_type
		var res: EnemyData = load(path) as EnemyData
		assert_object(res)\
			.override_failure_message("Wave config references enemy type '%s' but %s does not exist or is not EnemyData" % [enemy_type, path])\
			.is_not_null()


# ====================================================================================
# TOWER COST / DAMAGE SCALING TESTS
# ====================================================================================

func test_tower_cost_increases_with_tier() -> void:
	for i in range(BASE_TOWER_PATHS.size()):
		var base: TowerData = load(BASE_TOWER_PATHS[i]) as TowerData
		var enhanced: TowerData = base.upgrade_to
		var superior: TowerData = enhanced.upgrade_to
		assert_int(enhanced.cost)\
			.override_failure_message("Enhanced cost should exceed base cost for %s (enhanced=%d, base=%d)" % [base.tower_name, enhanced.cost, base.cost])\
			.is_greater(base.cost)
		assert_int(superior.cost)\
			.override_failure_message("Superior cost should exceed enhanced cost for %s (superior=%d, enhanced=%d)" % [base.tower_name, superior.cost, enhanced.cost])\
			.is_greater(enhanced.cost)


func test_tower_damage_increases_with_tier() -> void:
	for i in range(BASE_TOWER_PATHS.size()):
		var base: TowerData = load(BASE_TOWER_PATHS[i]) as TowerData
		var enhanced: TowerData = base.upgrade_to
		var superior: TowerData = enhanced.upgrade_to
		assert_int(enhanced.damage)\
			.override_failure_message("Enhanced damage should exceed base damage for %s (enhanced=%d, base=%d)" % [base.tower_name, enhanced.damage, base.damage])\
			.is_greater(base.damage)
		assert_int(superior.damage)\
			.override_failure_message("Superior damage should exceed enhanced damage for %s (superior=%d, enhanced=%d)" % [base.tower_name, superior.damage, enhanced.damage])\
			.is_greater(enhanced.damage)
