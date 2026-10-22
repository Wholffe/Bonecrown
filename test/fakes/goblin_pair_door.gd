class_name GoblinPairDoor
extends RefCounted
## Test helper: a door with two unscaled goblins, so a scene test starts that fight without a roll.

const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")


static func create() -> DoorOption:
	var encounter: EncounterData = EncounterData.new()
	encounter.enemies = [GOBLIN, GOBLIN]
	return DoorOption.new(encounter, Enemy.create_group(encounter.enemies))
