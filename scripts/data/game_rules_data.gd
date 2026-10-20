class_name GameRulesData
extends Resource
## Rule values that apply to every class.

@export var proficiency_bonus: int = 0
## Highest value an attribute can reach through skills and items.
@export var attribute_cap: int = 0
## Rooms per run. The last one is the boss room, every room before it is a fight.
@export var room_count: int = 0
