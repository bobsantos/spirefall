class_name MetaProgressionClass
extends Node

## Cross-run meta-progression: XP accumulation, threshold-based unlocks,
## and SaveSystem persistence. Registered as the MetaProgression autoload.

signal xp_awarded(amount: int, total: int)
signal unlocked(unlock_id: String)

const UNLOCK_THRESHOLDS: Dictionary = {
	"mode_draft": 500,
	"map_mountain_pass": 1000,
	"mode_endless": 2000,
	"map_river_delta": 3000,
	"map_volcanic_caldera": 6000,
}

var _total_xp: int = 0
var _unlocked: Array[String] = []


func _ready() -> void:
	_load_from_save()


## Restore state from SaveSystem on startup or after reset.
func _load_from_save() -> void:
	var prog: Dictionary = SaveSystem.get_progression()
	_total_xp = int(prog.get("total_xp", 0))
	_unlocked = []
	for id: String in UNLOCK_THRESHOLDS:
		if _total_xp >= UNLOCK_THRESHOLDS[id]:
			_unlocked.append(id)


## Calculate XP earned from a single run's stats.
func calculate_run_xp(run_stats: Dictionary) -> int:
	var base_xp: int = run_stats.get("waves_survived", 0) * 10
	var kill_bonus: int = run_stats.get("enemies_killed", 0) * 1
	var gold_bonus: int = int(floor(run_stats.get("total_gold_earned", 0) / 100.0)) * 5
	var victory_bonus: int = 200 if run_stats.get("victory", false) else 0
	return base_xp + kill_bonus + gold_bonus + victory_bonus


## Award XP, persist to SaveSystem, trigger unlocks, and emit signals.
func award_xp(amount: int) -> void:
	if amount <= 0:
		return

	var xp_before: int = _total_xp
	_total_xp += amount

	# Persist total XP
	SaveSystem._data["progression"]["total_xp"] = _total_xp

	# Check for new unlocks
	var new_unlocks: Array[String] = get_new_unlocks(xp_before, _total_xp)
	for id: String in new_unlocks:
		_unlocked.append(id)
		_persist_unlock(id)
		unlocked.emit(id)

	SaveSystem.save()
	xp_awarded.emit(amount, _total_xp)


## Returns true if the given unlock ID has been earned.
func is_unlocked(unlock_id: String) -> bool:
	return unlock_id in _unlocked


## Returns the total accumulated XP.
func get_total_xp() -> int:
	return _total_xp


## Returns unlock IDs whose thresholds fall in the range (xp_before, xp_after],
## sorted by threshold ascending.
func get_new_unlocks(xp_before: int, xp_after: int) -> Array[String]:
	var result: Array[String] = []
	# Collect qualifying unlocks with their thresholds for sorting
	var pairs: Array[Array] = []
	for id: String in UNLOCK_THRESHOLDS:
		var threshold: int = UNLOCK_THRESHOLDS[id]
		if xp_before < threshold and threshold <= xp_after:
			pairs.append([threshold, id])
	# Sort by threshold ascending
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair: Array in pairs:
		result.append(pair[1])
	return result


## Reset in-memory state (does not touch SaveSystem).
func reset() -> void:
	_total_xp = 0
	_unlocked = []


## Write an unlock ID into the appropriate SaveSystem list (maps or modes).
func _persist_unlock(unlock_id: String) -> void:
	var prog: Dictionary = SaveSystem._data["progression"]
	if unlock_id.begins_with("map_"):
		var maps: Array = prog["unlocked_maps"]
		if not maps.has(unlock_id):
			maps.append(unlock_id)
	elif unlock_id.begins_with("mode_"):
		var modes: Array = prog["unlocked_modes"]
		if not modes.has(unlock_id):
			modes.append(unlock_id)
