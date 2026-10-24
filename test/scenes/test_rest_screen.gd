extends GutTest
## Rest screen: the node's level-up, then healing a share of the new max HP.

const REST_SCENE: PackedScene = preload("res://scenes/map/rest_screen.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
const SEED: int = 7


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.enter_node(MapNode.new(5, 0, MapNode.Type.REST))


func _create() -> RestScreen:
	var screen: RestScreen = REST_SCENE.instantiate() as RestScreen
	add_child_autofree(screen)
	return screen


func test_rest_levels_up_and_heals_a_share_of_the_new_max_hit_points() -> void:
	RunState.player.take_damage(10)

	var screen: RestScreen = _create()

	var max_hit_points: int = RunState.player.max_hit_points
	var healed: int = floori(max_hit_points * ECONOMY.rest_heal_percent / 100.0)
	assert_eq(RunState.player.level, 2)
	assert_eq(RunState.player.hit_points, 4 + (max_hit_points - 14) + healed)
	assert_eq(
		(screen.get_node("%HealLabel") as Label).text, "You rest by the fire: +%d HP" % healed
	)


func test_continue_leads_to_the_skill_tree_with_a_point() -> void:
	var screen: RestScreen = _create()

	assert_eq((screen.get_node("%ContinueButton") as Button).text, "Skill Tree")
