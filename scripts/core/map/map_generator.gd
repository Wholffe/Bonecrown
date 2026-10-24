class_name MapGenerator
extends RefCounted
## Draws the map of a run from the map table: one fight in the first row, paths that wander at
## most one lane per row through the open rows without crossing, a rest before the boss and the
## boss. Then it rolls the node types of the open rows and seals some treasure behind checks.

const PERCENT_DIE_SIDES: int = 100
## A path keeps its lane, or moves one lane to the left or right.
const DRIFT_DIE_SIDES: int = 3
## Node types that never follow a node of the same type, so a path does not repeat them.
const NO_REPEAT_TYPES: Array[MapNode.Type] = [
	MapNode.Type.MERCHANT, MapNode.Type.REST, MapNode.Type.TREASURE
]

var _dice: DiceRoller
var _table: MapTableData


func _init(dice: DiceRoller, table: MapTableData) -> void:
	_dice = dice
	_table = table


func generate(row_count: int) -> RunMap:
	var map: RunMap = RunMap.new(row_count, _table.lane_count)
	var middle_lane: int = floori((_table.lane_count - 1) / 2.0)
	var first: MapNode = _add(map, RunMap.FIRST_ROW, middle_lane, MapNode.Type.FIGHT)
	var rest: MapNode = _add(map, _table.rest_row, middle_lane, MapNode.Type.REST)
	var boss: MapNode = _add(map, row_count, middle_lane, MapNode.Type.BOSS)
	_link(rest, boss)
	for path: int in _table.path_count:
		_draw_path(map, first, rest, floori(path * _table.lane_count / float(_table.path_count)))
	for row: int in range(RunMap.FIRST_ROW + 1, _table.rest_row):
		for node: MapNode in map.nodes_in_row(row):
			node.type = _roll_type(map, node)
	_ensure_type(map, MapNode.Type.ELITE, _table.elite_first_row)
	_ensure_type(map, MapNode.Type.MERCHANT, _table.merchant_first_row)
	_seal_treasure(map)
	return map


func _add(map: RunMap, row: int, lane: int, type: MapNode.Type) -> MapNode:
	var node: MapNode = MapNode.new(row, lane, type)
	map.nodes.append(node)
	return node


func _link(from: MapNode, to: MapNode) -> void:
	if not to in from.next_nodes:
		from.next_nodes.append(to)


func _draw_path(map: RunMap, first: MapNode, rest: MapNode, start_lane: int) -> void:
	var previous: MapNode = first
	var lane: int = start_lane
	for row: int in range(RunMap.FIRST_ROW + 1, _table.rest_row):
		if previous != first:
			lane = _next_lane(map, previous, row)
		var node: MapNode = map.node_at(row, lane)
		if node == null:
			node = _add(map, row, lane, MapNode.Type.UNSET)
		_link(previous, node)
		previous = node
	_link(previous, rest)


# A step that would cross another path's step goes straight ahead instead. Paths move at most one
# lane, so a straight step never crosses.
func _next_lane(map: RunMap, from: MapNode, row: int) -> int:
	var lane: int = clampi(from.lane + _dice.roll(DRIFT_DIE_SIDES) - 2, 0, _table.lane_count - 1)
	for node: MapNode in map.nodes_in_row(row - 1):
		for next: MapNode in node.next_nodes:
			if next.row != row:
				continue
			if (
				(node.lane < from.lane and next.lane > lane)
				or (node.lane > from.lane and next.lane < lane)
			):
				return from.lane
	return lane


func _roll_type(map: RunMap, node: MapNode) -> MapNode.Type:
	var weights: Dictionary[MapNode.Type, int] = {}
	for type: MapNode.Type in _type_weights():
		if node.row >= _first_row(type) and not _repeats(map, node, type):
			weights[type] = _type_weights()[type]
	var total: int = 0
	for type: MapNode.Type in weights:
		total += weights[type]
	if total == 0:
		return MapNode.Type.FIGHT
	var roll: int = _dice.roll(total)
	for type: MapNode.Type in weights:
		roll -= weights[type]
		if roll <= 0:
			return type
	return MapNode.Type.FIGHT


func _type_weights() -> Dictionary[MapNode.Type, int]:
	return {
		MapNode.Type.FIGHT: _table.fight_weight,
		MapNode.Type.ELITE: _table.elite_weight,
		MapNode.Type.MERCHANT: _table.merchant_weight,
		MapNode.Type.REST: _table.rest_weight,
		MapNode.Type.TREASURE: _table.treasure_weight,
	}


func _first_row(type: MapNode.Type) -> int:
	match type:
		MapNode.Type.ELITE:
			return _table.elite_first_row
		MapNode.Type.MERCHANT:
			return _table.merchant_first_row
		MapNode.Type.REST:
			return _table.rest_first_row
		MapNode.Type.TREASURE:
			return _table.treasure_first_row
	return RunMap.FIRST_ROW


func _repeats(map: RunMap, node: MapNode, type: MapNode.Type) -> bool:
	if not type in NO_REPEAT_TYPES:
		return false
	for parent: MapNode in map.parents_of(node):
		if parent.type == type:
			return true
	return false


# Every map offers at least one node of the type, so each run has an elite and a merchant to aim
# for. A fight node from the type's first row on becomes it.
func _ensure_type(map: RunMap, type: MapNode.Type, first_row: int) -> void:
	if map.count_of(type) > 0:
		return
	var candidates: Array[MapNode] = []
	for node: MapNode in map.nodes:
		if (
			node.type == MapNode.Type.FIGHT
			and node.row >= first_row
			and node.row > RunMap.FIRST_ROW
		):
			candidates.append(node)
	if candidates.is_empty():
		return
	candidates[_dice.roll(candidates.size()) - 1].type = type


func _seal_treasure(map: RunMap) -> void:
	if _table.skill_checks.is_empty():
		return
	for node: MapNode in map.nodes:
		if node.type != MapNode.Type.TREASURE:
			continue
		if _dice.roll(PERCENT_DIE_SIDES) <= _table.sealed_treasure_chance_percent:
			node.check = _table.skill_checks[_dice.roll(_table.skill_checks.size()) - 1]
