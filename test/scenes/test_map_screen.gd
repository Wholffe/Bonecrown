extends GutTest
## Map screen: a button per node, the first node selected, details with the node's type and check,
## Enter only for the nodes the player can go to next, and where each node type leads.

const MAP_SCENE: PackedScene = preload("res://scenes/map/map_screen.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 7
## [node type, scene path the node leads to]
const SCENE_CASES: Array = [
	[MapNode.Type.FIGHT, MapScreen.BATTLE_SCENE_PATH],
	[MapNode.Type.ELITE, MapScreen.BATTLE_SCENE_PATH],
	[MapNode.Type.BOSS, MapScreen.BATTLE_SCENE_PATH],
	[MapNode.Type.MERCHANT, MapScreen.MERCHANT_SCENE_PATH],
	[MapNode.Type.REST, MapScreen.REST_SCENE_PATH],
	[MapNode.Type.TREASURE, MapScreen.TREASURE_SCENE_PATH],
]


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)


func _create() -> MapScreen:
	var screen: MapScreen = MAP_SCENE.instantiate() as MapScreen
	add_child_autofree(screen)
	return screen


func _view(screen: MapScreen) -> MapView:
	return screen.get_node("%MapView") as MapView


func _label_text(screen: MapScreen, node_name: String) -> String:
	return (screen.get_node("%" + node_name) as Label).text


func _enter_button(screen: MapScreen) -> Button:
	return screen.get_node("%EnterButton") as Button


func test_every_node_gets_a_button() -> void:
	var screen: MapScreen = _create()

	for node: MapNode in RunState.map.nodes:
		assert_not_null(_view(screen).node_button(node.row, node.lane), "row %d" % node.row)


func test_first_fight_is_selected_and_can_be_entered() -> void:
	var screen: MapScreen = _create()

	assert_eq(screen.selected_node(), RunState.map.start_nodes()[0])
	assert_eq(_label_text(screen, "NodeNameLabel"), "Fight")
	assert_string_contains(_label_text(screen, "NodeDetailsLabel"), "You can go here next.")
	assert_false(_enter_button(screen).disabled)


func test_later_nodes_cannot_be_entered_yet() -> void:
	var screen: MapScreen = _create()
	var boss: MapNode = RunState.map.nodes_in_row(RunState.map.row_count)[0]

	screen.select_node(boss)

	assert_eq(_label_text(screen, "NodeNameLabel"), "Boss")
	assert_true(_enter_button(screen).disabled)


func test_status_shows_level_hit_points_and_gold() -> void:
	RunState.player.gold = 42

	var screen: MapScreen = _create()

	assert_eq(_label_text(screen, "StatusLabel"), "Level 1   ·   HP 14 / 14   ·   Gold 42")


func test_sealed_treasure_names_its_check() -> void:
	var node: MapNode = MapNode.new(3, 0, MapNode.Type.TREASURE)
	node.check = RunState.MAP_TABLE.skill_checks[0]
	RunState.map.nodes.append(node)
	var screen: MapScreen = _create()

	screen.select_node(node)

	assert_eq(_label_text(screen, "NodeNameLabel"), "Sealed Treasure: Rusted Lock")
	assert_string_contains(
		_label_text(screen, "NodeDetailsLabel"), "Sealed: Strength check, d20+3 against 14."
	)


func test_nodes_behind_the_walked_path_cannot_be_reached() -> void:
	var first: MapNode = RunState.map.start_nodes()[0]
	RunState.enter_node(first)
	var row_two: Array[MapNode] = RunState.map.nodes_in_row(2)
	var chosen: MapNode = row_two[0]
	RunState.enter_node(chosen)
	var screen: MapScreen = _create()
	var others: Array[MapNode] = row_two.filter(func(node: MapNode) -> bool: return node != chosen)
	if others.is_empty():
		pass_test("row 2 has a single node for this seed")
		return

	screen.select_node(others[0])

	assert_string_contains(
		_label_text(screen, "NodeDetailsLabel"), "You cannot reach this node anymore."
	)
	assert_true(_enter_button(screen).disabled)


# The scene change itself would replace the running GUT scene, so only its target is checked.
func test_each_node_type_leads_to_its_scene(params: Array = use_parameters(SCENE_CASES)) -> void:
	var node: MapNode = MapNode.new(2, 0, params[0])

	assert_eq(MapScreen.node_scene_path(node), params[1])
	assert_true(ResourceLoader.exists(params[1]), params[1])


func test_reachable_from_follows_every_path() -> void:
	var start: Array[MapNode] = RunState.map.start_nodes()

	var reachable: Array[MapNode] = MapView.reachable_from(start)

	assert_eq(reachable.size(), RunState.map.nodes.size(), "every node lies on a path")
