class_name ClassData
extends Resource
## Data of a playable class: fixed starting attributes, hit points, equipment and skills.

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
@export var starting_skills: Array[SkillData] = []
## Every level-up gives a point to spend in it.
@export var skill_tree: SkillTreeData
## Idle animation of the battle figure, facing right.
@export var figure_frames: Array[Texture2D] = []
