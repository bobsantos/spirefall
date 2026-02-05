class_name StatusEffect
extends RefCounted

## Lightweight status effect data. Stored in Enemy._status_effects array.
## Not a Node -- just a data container ticked by Enemy._process().

enum Type { BURN, SLOW, FREEZE }

var type: Type
var duration: float          # Total remaining seconds
var value: float             # Burn: damage per second; Slow: speed reduction 0-1 (0.3 = 30%)
var elapsed: float = 0.0     # Time accumulated since last damage tick (burn only)


func _init(p_type: Type, p_duration: float, p_value: float) -> void:
	type = p_type
	duration = p_duration
	value = p_value


func tick(delta: float) -> float:
	## Advance the effect by delta seconds. Returns burn damage dealt this frame
	## (0.0 for non-burn effects). Duration is decremented automatically.
	duration -= delta
	if type == Type.BURN:
		elapsed += delta
		if elapsed >= 1.0:
			elapsed -= 1.0
			return value
	return 0.0


func is_expired() -> bool:
	return duration <= 0.0


static func type_to_string(t: Type) -> String:
	match t:
		Type.BURN:
			return "burn"
		Type.SLOW:
			return "slow"
		Type.FREEZE:
			return "freeze"
	return "unknown"
