extends GutTest
## RunMap and MapNode: nodes by row in lane order, lookups, parents, counts and fight nodes.

var _map: RunMap
var _first: MapNode
var _left: MapNode
var _right: MapNode


func before_each() -> void:
	_map = RunMap.new(3, 2)
	_first = MapNode.new(1, 0, MapNode.Type.FIGHT)
	_right = MapNode.new(2, 1, MapNode.Type.MERCHANT)
	_left = MapNode.new(2, 0, MapNode.Type.ELITE)
	_first.next_nodes = [_right, _left]
	_map.nodes = [_first, _right, _left]


func test_nodes_in_row_come_in_lane_order() -> void:
	assert_eq(_map.nodes_in_row(2), [_left, _right] as Array[MapNode])
	assert_eq(_map.start_nodes(), [_first] as Array[MapNode])


func test_node_at_finds_the_place_or_nothing() -> void:
	assert_eq(_map.node_at(2, 1), _right)
	assert_null(_map.node_at(3, 0))


func test_parents_are_the_nodes_that_lead_to_a_node() -> void:
	assert_eq(_map.parents_of(_left), [_first] as Array[MapNode])
	assert_true(_map.parents_of(_first).is_empty())


func test_count_of_counts_a_type() -> void:
	assert_eq(_map.count_of(MapNode.Type.ELITE), 1)
	assert_eq(_map.count_of(MapNode.Type.REST), 0)


func test_fights_are_fight_elite_and_boss_nodes() -> void:
	assert_true(_first.is_fight())
	assert_true(_left.is_fight())
	assert_true(MapNode.new(3, 0, MapNode.Type.BOSS).is_fight())
	assert_false(_right.is_fight())
	assert_false(MapNode.new(3, 0, MapNode.Type.TREASURE).is_fight())
