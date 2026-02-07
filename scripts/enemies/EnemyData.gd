class_name EnemyData
extends Resource

## Data definition for an enemy type.

@export var enemy_name: String = ""
@export var base_health: int = 100
@export var speed_multiplier: float = 1.0  # 1.0 = normal speed (64 px/s)
@export var gold_reward: int = 3
@export var element: String = "none"  # Elemental affinity for damage matrix
@export var special: String = ""  # e.g. "50% physical resist", "ignores maze"
@export var physical_resist: float = 0.0  # 0.0-1.0: fraction of earth/physical damage resisted
@export var is_flying: bool = false
@export var is_boss: bool = false
@export var spawn_count: int = 1  # Swarm enemies spawn in groups
@export var split_on_death: bool = false
@export var split_data: EnemyData = null  # What to split into
@export var stealth: bool = false
@export var heal_per_second: float = 0.0  # For Healer type aura
@export var immune_element: String = ""  # Elemental type: immune to this element (damage = 0)
@export var weak_element: String = ""  # Elemental type: takes 2x damage from this element
