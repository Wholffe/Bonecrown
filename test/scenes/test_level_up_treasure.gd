extends GutTest
## Post-fight screen at a treasure node: its title and gold, the loot bonus, and a sealed
## treasure's check that opens the loot roll or costs hit points.

const LEVEL_UP_SCENE: PackedScene = preload("res://scenes/levelup/level_up.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
const MAP_TABLE: MapTableData = preload("res://scripts/data/map/map_table.tres")
const SEED: int = 7
## Rusted Lock: Strength check against 14, the Warrior's bonus is +3.
const PASSING_ROLL: int = 11
const FAILING_ROLL: int = 10


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)


func _create(sealed: bool, rolls: Array[int]) -> LevelUp:
	var node: MapNode = MapNode.new(3, 0, MapNode.Type.TREASURE)
	if sealed:
		node.check = MAP_TABLE.skill_checks[0]
	RunState.enter_node(node)
	RunState.dice = FixedDice.new(rolls)
	var level_up: LevelUp = LEVEL_UP_SCENE.instantiate() as LevelUp
	level_up.set_animations_enabled(false)
	add_child_autofree(level_up)
	return level_up


func _label_text(level_up: LevelUp, node_name: String) -> String:
	return (level_up.get_node("%" + node_name) as Label).text


func _button(level_up: LevelUp, node_name: String) -> Button:
	return level_up.get_node("%" + node_name) as Button


func _press(level_up: LevelUp, node_name: String) -> void:
	_button(level_up, node_name).pressed.emit()
	await wait_process_frames(1)


func test_treasure_gives_its_gold_and_loot_bonus() -> void:
	var level_up: LevelUp = _create(false, [])

	assert_eq(_label_text(level_up, "TitleLabel"), "Treasure")
	assert_eq(RunState.player.gold, ECONOMY.treasure_gold)
	assert_string_contains(
		_label_text(level_up, "LootInfoLabel"), "d20%+d" % ECONOMY.treasure_loot_bonus
	)
	assert_true(_button(level_up, "RollButton").visible)


func test_sealed_treasure_asks_for_its_check_first() -> void:
	var level_up: LevelUp = _create(true, [])

	assert_eq(_label_text(level_up, "TitleLabel"), "Sealed Treasure: Rusted Lock")
	assert_false(_button(level_up, "RollButton").visible)
	assert_true(_button(level_up, "CheckButton").visible)
	assert_eq(
		_button(level_up, "CheckButton").text,
		"Force the rusted lock: Strength check d20+3 against 14"
	)
	assert_eq(RunState.player.gold, 0, "no gold before the check")


func test_passed_check_opens_the_loot_roll_and_gives_the_gold() -> void:
	var level_up: LevelUp = _create(true, [PASSING_ROLL])

	await _press(level_up, "CheckButton")

	assert_false(_button(level_up, "CheckButton").visible)
	assert_true(_button(level_up, "RollButton").visible)
	assert_eq(RunState.player.gold, ECONOMY.treasure_gold)
	assert_eq(RunState.player.hit_points, RunState.player.max_hit_points)


func test_failed_check_costs_hit_points_and_ends_the_node() -> void:
	var level_up: LevelUp = _create(true, [FAILING_ROLL])
	var fail_damage: int = MAP_TABLE.skill_checks[0].fail_damage

	await _press(level_up, "CheckButton")

	assert_eq(RunState.player.hit_points, RunState.player.max_hit_points - fail_damage)
	assert_false(_button(level_up, "RollButton").visible)
	assert_true(_button(level_up, "NextButton").visible)
	assert_eq(_label_text(level_up, "FindLabel"), "The treasure stays sealed. −%d HP" % fail_damage)
