class_name GoblinPairNode
extends RefCounted
## Test helper: a fight node in room 2 with two unscaled goblins, so a scene test starts that fight
## without a roll.

const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const ROOM: int = 2


static func create() -> MapNode:
	var node: MapNode = MapNode.new(ROOM, 0, MapNode.Type.FIGHT)
	var goblins: Array[EnemyData] = [GOBLIN, GOBLIN]
	node.enemies = Enemy.create_group(goblins)
	return node
