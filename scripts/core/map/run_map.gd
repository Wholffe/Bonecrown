class_name RunMap
extends RefCounted
## The map of one run: its nodes from the first fight to the boss, one row per room.

const FIRST_ROW: int = 1

var row_count: int
var lane_count: int
var nodes: Array[MapNode] = []


func _init(rows: int, lanes: int) -> void:
	row_count = rows
	lane_count = lanes


## Left to right.
func nodes_in_row(row: int) -> Array[MapNode]:
	var in_row: Array[MapNode] = []
	for node: MapNode in nodes:
		if node.row == row:
			in_row.append(node)
	in_row.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.lane < b.lane)
	return in_row


## Null when the place is empty.
func node_at(row: int, lane: int) -> MapNode:
	for node: MapNode in nodes:
		if node.row == row and node.lane == lane:
			return node
	return null


func start_nodes() -> Array[MapNode]:
	return nodes_in_row(FIRST_ROW)


## The nodes of the row before that lead to the node.
func parents_of(node: MapNode) -> Array[MapNode]:
	var parents: Array[MapNode] = []
	for candidate: MapNode in nodes:
		if node in candidate.next_nodes:
			parents.append(candidate)
	return parents


func count_of(type: MapNode.Type) -> int:
	var count: int = 0
	for node: MapNode in nodes:
		if node.type == type:
			count += 1
	return count
