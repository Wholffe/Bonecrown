class_name EnemyData
extends Resource
## Data of an enemy type before room scaling.

@export var id: StringName
@export var display_name: String
@export var armor_class: int = 0
@export var max_hit_points: int = 0
@export var attack_bonus: int = 0
@export var damage_die_count: int = 0
@export var damage_die_sides: int = 0
@export var damage_bonus: int = 0
## Crits against this enemy still hit, but roll the damage dice only once.
@export var crit_resistant: bool = false
@export var starting_momentum: int = 0
@export var momentum_per_round: int = 0
@export var momentum_cap: int = 0
## Ordered by Momentum cost, the first one costs nothing.
@export var intents: Array[EnemyIntentData] = []
## Idle animation of the battle figure, facing right. The battle mirrors it to face the player.
@export var figure_frames: Array[Texture2D] = []
## Size of the battle figure relative to the others, so a boss can tower over them.
@export var figure_scale: float = 1.0
