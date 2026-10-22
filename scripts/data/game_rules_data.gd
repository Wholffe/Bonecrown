class_name GameRulesData
extends Resource
## Rule values that apply to every class.

@export var proficiency_bonus: int = 0
## Highest value an attribute can reach through skills and items.
@export var attribute_cap: int = 0
## Rooms per run. The last one is the boss room, every room before it is a fight.
@export var room_count: int = 0
@export_group("Momentum")
@export var momentum_at_fight_start: int = 0
## Gained at the start of every round after the first.
@export var momentum_per_round: int = 0
## Unused Momentum carries over up to this value.
@export var momentum_cap: int = 0
@export var attack_momentum_cost: int = 0
@export var block_momentum_cost: int = 0
## Gained for every enemy attack that misses the player.
@export var momentum_per_fended_attack: int = 0
@export var momentum_per_kill: int = 0
