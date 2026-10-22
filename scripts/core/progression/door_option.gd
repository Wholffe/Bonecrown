class_name DoorOption
extends RefCounted
## One door before a fight: the encounter behind it, its enemies and the reward it may carry.

var encounter: EncounterData
## Already scaled to the room, so the door shows the stats of the fight and the fight uses them.
var enemies: Array[Combatant]
## Given after the fight behind the door is won. Null for a door without a reward.
var reward: DoorRewardData = null


func _init(door_encounter: EncounterData, door_enemies: Array[Combatant]) -> void:
	encounter = door_encounter
	enemies = door_enemies
