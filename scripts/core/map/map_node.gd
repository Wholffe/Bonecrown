class_name MapNode
extends RefCounted
## One node of the run's map: its type, its place and the nodes of the next row it leads to.

enum Type { FIGHT = 0, ELITE = 1, MERCHANT = 2, REST = 3, TREASURE = 4, BOSS = 5, UNSET = -1 }

var type: Type = Type.UNSET
## Rows count from 1 like rooms: the row is the room number of the node.
var row: int
## Column on the map, 0 for the left lane.
var lane: int
var next_nodes: Array[MapNode] = []
## The check that seals a treasure node, or null.
var check: SkillCheckData = null
## The enemies of a fight node, created when the player enters it. Empty before.
var enemies: Array[Combatant] = []


func _init(node_row: int, node_lane: int, node_type: Type = Type.UNSET) -> void:
	row = node_row
	lane = node_lane
	type = node_type


func is_fight() -> bool:
	return type == Type.FIGHT or type == Type.ELITE or type == Type.BOSS
