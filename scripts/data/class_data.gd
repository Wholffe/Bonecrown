class_name ClassData
extends Resource
## Data of a playable class: fixed starting attributes, hit points and starting equipment.

@export var id: StringName
@export var display_name: String
@export var strength: int = 0
@export var dexterity: int = 0
@export var constitution: int = 0
@export var luck: int = 0
@export var base_hit_points: int = 0
@export var hit_points_per_level: int = 0
@export var starting_weapon: WeaponData
@export var starting_armor: ArmorData
