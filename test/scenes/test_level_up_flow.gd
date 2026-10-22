extends GutTest
## Post-fight screen: the roll buttons, the Choose buttons of the skill cards, an empty skill offer
## and where the Next button leads.

const LEVEL_UP_SCENE: PackedScene = preload("res://scenes/levelup/level_up.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 7
const BLOOD_PRICE_ROOM: int = 2
## Loot d20 5 (common), first common item, then the first candidate for each of the 3 cards.
const COMMON_FIND_ROLLS: Array[int] = [5, 1, 1, 1, 1]
## Loot d20 5 (common), first common item. An empty pool rolls no cards.
const COMMON_FIND_WITHOUT_CARDS_ROLLS: Array[int] = [5, 1]
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


## Rolls a common find, leaves it and returns the Choose buttons of the cards in card order.
func _open_skill_cards(level_up: LevelUp) -> Array[Button]:
	await _press(level_up, "RollButton")
	await _press(level_up, "LeaveButton")
	var buttons: Array[Button] = []
	for button: Node in level_up.get_node("%SkillCards").find_children("*", "Button", true, false):
		buttons.append(button as Button)
	return buttons


func test_either_roll_button_disables_both(
	params: Array = use_parameters(ROLL_BUTTON_CASES)
) -> void:
	RunState.room_number = BLOOD_PRICE_ROOM
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)

	await _press(level_up, params[0])

	assert_true(_button(level_up, "RollButton").disabled, "after %s" % params[0])
	assert_true(_button(level_up, "BloodPriceButton").disabled, "after %s" % params[0])


func test_choose_button_disables_every_card() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)
	var buttons: Array[Button] = await _open_skill_cards(level_up)
	assert_eq(buttons.size(), 3)

	buttons[0].pressed.emit()

	for index: int in buttons.size():
		assert_true(buttons[index].disabled, "card %d" % index)
	assert_has(RunState.player.skills, level_up.offered_skills()[0])


func test_second_choose_button_learns_no_second_skill() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)
	var buttons: Array[Button] = await _open_skill_cards(level_up)
	var offer: Array[SkillData] = level_up.offered_skills()

	buttons[0].pressed.emit()
	buttons[1].pressed.emit()

	assert_eq(RunState.player.skills.size(), WARRIOR.starting_skills.size() + 1)
	assert_eq(RunState.player.skills.count(offer[0]), 1)
	assert_does_not_have(RunState.player.skills, offer[1])


func test_empty_skill_offer_shows_next_at_once() -> void:
	var class_without_pool: ClassData = WARRIOR.duplicate()
	var no_skills: Array[SkillData] = []
	class_without_pool.skill_pool = no_skills
	RunState.start_new_run(class_without_pool, SEED)
	var level_up: LevelUp = _create(COMMON_FIND_WITHOUT_CARDS_ROLLS)

	await _press(level_up, "RollButton")
	await _press(level_up, "LeaveButton")

	assert_true(level_up.offered_skills().is_empty())
	assert_eq(level_up.get_node("%SkillCards").get_child_count(), 0)
	assert_true(_button(level_up, "NextButton").visible)


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
