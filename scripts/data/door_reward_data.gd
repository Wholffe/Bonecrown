class_name DoorRewardData
extends Resource
## A reward shown on a door before the fight. It is given after the fight behind that door is won.

@export var id: StringName
@export var display_name: String
## Shown on the door after the name, for example "+3 on the loot roll after this fight."
@export var description: String
## Added to the loot roll after the fight.
@export var loot_bonus: int = 0
## Share of the player's max hit points healed after the fight, rounded down.
@export var heal_percent: int = 0
