extends GutTest
## Post-fight screen: the roll buttons, a class without a skill tree and where the Next button
## leads.

const LEVEL_UP_SCENE: PackedScene = preload("res://scenes/levelup/level_up.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 7
const BLOOD_PRICE_ROOM: int = 2
## Loot d20 5 (common), first common item.
const COMMON_FIND_ROLLS: Array[int] = [5, 1]
## [button pressed to roll the loot] in the Blood Price room.
const ROLL_BUTTON_CASES: Array = [["RollButton"], ["BloodPriceButton"]]
## [room just cleared], each followed by a room with a door choice.
const CLEARED_ROOM_CASES: Array = [[1], [2], [3], [4], [5], [6], [7], [8]]


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)


func _create(rolls: Array[int]) -> LevelUp:
	RunState.dice = FixedDice.new(rolls)
	var level_up: LevelUp = LEVEL_UP_SCENE.instantiate() as LevelUp
	level_up.set_animations_enabled(false)
	add_child_autofree(level_up)
	return level_up


func _button(level_up: LevelUp, node_name: String) -> Button:
	return level_up.get_node("%" + node_name) as Button


func _press(level_up: LevelUp, node_name: String) -> void:
	_button(level_up, node_name).pressed.emit()
	await wait_process_frames(1)


func test_either_roll_button_disables_both(
	params: Array = use_parameters(ROLL_BUTTON_CASES)
) -> void:
	RunState.room_number = BLOOD_PRICE_ROOM
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)

	await _press(level_up, params[0])

	assert_true(_button(level_up, "RollButton").disabled, "after %s" % params[0])
	assert_true(_button(level_up, "BloodPriceButton").disabled, "after %s" % params[0])


func test_class_without_a_skill_tree_goes_to_the_next_room() -> void:
	var class_without_tree: ClassData = WARRIOR.duplicate()
	class_without_tree.skill_tree = null
	RunState.start_new_run(class_without_tree, SEED)
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)

	await _press(level_up, "RollButton")
	await _press(level_up, "LeaveButton")

	assert_null(RunState.skill_tree)
	assert_false(LevelUp.has_skill_point_to_spend())
	assert_eq(_button(level_up, "NextButton").text, "Next Room")


# Next advances the room and then changes to room_scene_path(). The scene change itself would
# replace the running GUT scene, so only its target is checked.
func test_next_after_a_fight_room_leads_to_the_door_choice(
	params: Array = use_parameters(CLEARED_ROOM_CASES)
) -> void:
	RunState.room_number = params[0]

	RunState.advance_room()

	assert_eq(
		LevelUp.room_scene_path(), LevelUp.DOOR_CHOICE_SCENE_PATH, "after room %d" % params[0]
	)


func test_next_after_the_last_fight_room_leads_to_the_boss_battle() -> void:
	RunState.room_number = RunState.GAME_RULES.room_count - 1

	RunState.advance_room()

	assert_true(RunState.is_boss_room())
	assert_eq(LevelUp.room_scene_path(), LevelUp.BATTLE_SCENE_PATH)
