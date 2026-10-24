extends GutTest
## MapGenerator on the real map table over many seeds: fixed rows, connected paths that move at
## most one lane and never cross, node types by row, at least one elite and one merchant, and
## sealed treasure.

const MAP_TABLE: MapTableData = preload("res://scripts/data/map/map_table.tres")
const ROW_COUNT: int = 10
const SEED_COUNT: int = 40
const NO_REPEAT_TYPES: Array[MapNode.Type] = [
	MapNode.Type.MERCHANT, MapNode.Type.REST, MapNode.Type.TREASURE
]

var _maps: Array[RunMap] = []


func before_all() -> void:
	for seed_value: int in SEED_COUNT:
		_maps.append(MapGenerator.new(DiceRoller.new(seed_value), MAP_TABLE).generate(ROW_COUNT))


func _first_row_of(type: MapNode.Type) -> int:
	match type:
		MapNode.Type.ELITE:
			return MAP_TABLE.elite_first_row
		MapNode.Type.MERCHANT:
			return MAP_TABLE.merchant_first_row
		MapNode.Type.REST:
			return MAP_TABLE.rest_first_row
		MapNode.Type.TREASURE:
			return MAP_TABLE.treasure_first_row
	return RunMap.FIRST_ROW


func _is_open_row(row: int) -> bool:
	return row > RunMap.FIRST_ROW and row < MAP_TABLE.rest_row


func test_fixed_rows_hold_one_fight_one_rest_and_the_boss() -> void:
	for map: RunMap in _maps:
		var first: Array[MapNode] = map.nodes_in_row(RunMap.FIRST_ROW)
		var rest: Array[MapNode] = map.nodes_in_row(MAP_TABLE.rest_row)
		var boss: Array[MapNode] = map.nodes_in_row(ROW_COUNT)
		assert_eq(first.size(), 1)
		assert_eq(first[0].type, MapNode.Type.FIGHT)
		assert_eq(rest.size(), 1)
		assert_eq(rest[0].type, MapNode.Type.REST)
		assert_eq(boss.size(), 1)
		assert_eq(boss[0].type, MapNode.Type.BOSS)
		assert_eq(rest[0].next_nodes, boss)
		assert_true(boss[0].next_nodes.is_empty(), "the boss is the end")


func test_every_node_leads_to_the_next_row_and_is_reached() -> void:
	for map: RunMap in _maps:
		for node: MapNode in map.nodes:
			for next: MapNode in node.next_nodes:
				assert_eq(next.row, node.row + 1, "a step goes one row on")
			if node.row != ROW_COUNT:
				assert_false(node.next_nodes.is_empty(), "row %d leads on" % node.row)
			if node.row != RunMap.FIRST_ROW:
				assert_false(map.parents_of(node).is_empty(), "row %d is reached" % node.row)


func test_open_rows_fill_the_lanes_and_paths_move_at_most_one_lane() -> void:
	for map: RunMap in _maps:
		for node: MapNode in map.nodes:
			assert_between(node.lane, 0, MAP_TABLE.lane_count - 1)
			if not _is_open_row(node.row):
				continue
			for next: MapNode in node.next_nodes:
				if _is_open_row(next.row):
					assert_lte(absi(next.lane - node.lane), 1, "row %d" % node.row)


func test_paths_never_cross() -> void:
	for map: RunMap in _maps:
		for row: int in range(RunMap.FIRST_ROW + 1, MAP_TABLE.rest_row - 1):
			var steps: Array[Vector2i] = []
			for node: MapNode in map.nodes_in_row(row):
				for next: MapNode in node.next_nodes:
					steps.append(Vector2i(node.lane, next.lane))
			for a: Vector2i in steps:
				for b: Vector2i in steps:
					var crosses: bool = (a.x < b.x and a.y > b.y) or (a.x > b.x and a.y < b.y)
					assert_false(crosses, "row %d: %s and %s cross" % [row, a, b])


func test_open_rows_hold_typed_nodes_from_their_first_row_on() -> void:
	for map: RunMap in _maps:
		for node: MapNode in map.nodes:
			assert_ne(node.type, MapNode.Type.UNSET, "row %d" % node.row)
			if _is_open_row(node.row):
				assert_ne(node.type, MapNode.Type.BOSS)
				assert_gte(node.row, _first_row_of(node.type), "type %d" % node.type)


func test_merchants_rests_and_treasure_do_not_repeat_on_a_path() -> void:
	for map: RunMap in _maps:
		for node: MapNode in map.nodes:
			if not _is_open_row(node.row) or not node.type in NO_REPEAT_TYPES:
				continue
			for parent: MapNode in map.parents_of(node):
				assert_ne(parent.type, node.type, "row %d" % node.row)


func test_every_map_has_an_elite_and_a_merchant() -> void:
	for map: RunMap in _maps:
		assert_gt(map.count_of(MapNode.Type.ELITE), 0, "elite")
		assert_gt(map.count_of(MapNode.Type.MERCHANT), 0, "merchant")


func test_only_treasure_is_sealed_and_some_treasure_is() -> void:
	var sealed_count: int = 0
	for map: RunMap in _maps:
		for node: MapNode in map.nodes:
			if node.check != null:
				sealed_count += 1
				assert_eq(node.type, MapNode.Type.TREASURE)
	assert_gt(sealed_count, 0, "No sealed treasure in %d maps" % SEED_COUNT)


func test_paths_offer_choices() -> void:
	for map: RunMap in _maps:
		var widest: int = 0
		for row: int in range(RunMap.FIRST_ROW + 1, MAP_TABLE.rest_row):
			widest = maxi(widest, map.nodes_in_row(row).size())
		assert_gt(widest, 1, "a map without a choice")


func test_same_seed_draws_the_same_map() -> void:
	var again: RunMap = MapGenerator.new(DiceRoller.new(0), MAP_TABLE).generate(ROW_COUNT)

	assert_eq(again.nodes.size(), _maps[0].nodes.size())
	for index: int in again.nodes.size():
		assert_eq(again.nodes[index].row, _maps[0].nodes[index].row)
		assert_eq(again.nodes[index].lane, _maps[0].nodes[index].lane)
		assert_eq(again.nodes[index].type, _maps[0].nodes[index].type)
