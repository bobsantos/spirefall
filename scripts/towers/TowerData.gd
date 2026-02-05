class_name TowerData
extends Resource

## Data definition for a tower type. Saved as .tres files.

@export var tower_name: String = ""
@export var element: String = "fire"  # fire, water, earth, wind, lightning, ice
@export var tier: int = 1  # 1=Base, 2=Dual Fusion, 3=Legendary
@export var cost: int = 30
@export var damage: int = 15
@export var attack_speed: float = 1.0  # Attacks per second
@export var range_cells: int = 4
@export var damage_type: String = "fire"  # Matches element for base towers
@export var special_description: String = ""
@export var special_key: String = ""  # "burn", "slow", "aoe", "freeze", or "" for none
@export var special_value: float = 0.0  # Burn: dmg/s, Slow: 0-1 fraction, Freeze: unused
@export var special_duration: float = 0.0  # Seconds for burn/slow/freeze
@export var special_chance: float = 1.0  # Proc chance 0-1 (1.0 = always, 0.2 = 20%)
@export var aoe_radius_cells: float = 0.0  # AoE radius in cells (0 = single-target)
@export var icon: Texture2D = null
@export var projectile_scene: PackedScene = null
@export var upgrade_to: TowerData = null  # Next tier of same element
@export var fusion_elements: Array[String] = []  # Elements required for fusion
