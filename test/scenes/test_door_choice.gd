extends GutTest
## Door choice: the door cards with their enemies and rewards, focus and choosing a door.

const DOOR_CHOICE_SCENE: PackedScene = preload("res://scenes/doors/door_choice.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 7
const DOOR_ROOM: int = 2
const ELITE_ROOM: int = 5
## Room 2: d2 = 1 puts the goblin pair behind the left door and the single goblin behind the right
## one. d100 = 1 hits the reward chance, d2 = 1 picks the Treasure for the harder left door.
const TREASURE_LEFT_ROLLS: Array[int] = [1, 1, 1]
## Room 2: the single goblin on the left, the pair on the right with the Healing Spring.
const HEALING_SPRING_RIGHT_ROLLS: Array[int] = [2, 1, 2]
## Room 2: the goblin pair on the left, d100 = 100 misses the reward chance.
const NO_REWARD_ROLLS: Array[int] = [1, 100]
const GOBLIN_LINE: String = "Goblin · AC 12 · HP 8 · Attack +3 · 1d6+1"


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)


func _create(room: int, rolls: Array[int]) -> DoorChoice:
	RunState.room_number = room
	RunState.dice = FixedDice.new(rolls)
	var door_choice: DoorChoice = DOOR_CHOICE_SCENE.instantiate() as DoorChoice
	add_child_autofree(door_choice)
	return door_choice


func _cards(door_choice: DoorChoice) -> Array[Node]:
	return door_choice.get_node("%DoorCards").get_children()


func _card_texts(door_choice: DoorChoice, index: int) -> Array[String]:
	var texts: Array[String] = []
	for label: Node in _cards(door_choice)[index].find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func _enter_button(door_choice: DoorChoice, index: int) -> Button:
	return _cards(door_choice)[index].find_children("*", "Button", true, false)[0] as Button


func test_opening_shows_the_room_and_the_player_hit_points() -> void:
	RunState.player.take_damage(3)
	var door_choice: DoorChoice = _create(DOOR_ROOM, NO_REWARD_ROLLS)

	assert_eq((door_choice.get_node("%TitleLabel") as Label).text, "Room 2")
	assert_eq((door_choice.get_node("%HitPointsLabel") as Label).text, "HP 11/14")


func test_two_door_cards_side_by_side_with_enter_buttons() -> void:
	var door_choice: DoorChoice = _create(DOOR_ROOM, NO_REWARD_ROLLS)

	assert_eq(_cards(door_choice).size(), 2)
	assert_eq(door_choice.doors().size(), 2)
	assert_has(_card_texts(door_choice, 0), "Left Door")
	assert_has(_card_texts(door_choice, 1), "Right Door")
	assert_eq(_enter_button(door_choice, 0).text, "Enter")
	assert_eq(_enter_button(door_choice, 1).text, "Enter")


func test_door_cards_list_the_enemies_with_their_stats() -> void:
	var door_choice: DoorChoice = _create(DOOR_ROOM, NO_REWARD_ROLLS)

	var left_texts: Array[String] = _card_texts(door_choice, 0)
	assert_has(left_texts, "Goblin 1 · AC 12 · HP 8 · Attack +3 · 1d6+1")
	assert_has(left_texts, "Goblin 2 · AC 12 · HP 8 · Attack +3 · 1d6+1")
	assert_has(_card_texts(door_choice, 1), GOBLIN_LINE)


func test_reward_line_shows_on_the_harder_door() -> void:
	var door_choice: DoorChoice = _create(DOOR_ROOM, TREASURE_LEFT_ROLLS)

	assert_has(_card_texts(door_choice, 0), "Treasure: +3 on the loot roll after this fight.")
	assert_eq(_card_texts(door_choice, 1), ["Right Door", GOBLIN_LINE] as Array[String])


func test_reward_line_can_show_on_the_right_door() -> void:
	var door_choice: DoorChoice = _create(DOOR_ROOM, HEALING_SPRING_RIGHT_ROLLS)

	assert_eq(_card_texts(door_choice, 0), ["Left Door", GOBLIN_LINE] as Array[String])
	assert_has(
		_card_texts(door_choice, 1), "Healing Spring: Heal 10% of your max HP after this fight."
	)


func test_no_reward_line_when_the_chance_misses() -> void:
	var door_choice: DoorChoice = _create(DOOR_ROOM, NO_REWARD_ROLLS)

	for door: DoorOption in door_choice.doors():
		assert_null(door.reward)
	assert_eq(_card_texts(door_choice, 1), ["Right Door", GOBLIN_LINE] as Array[String])


func test_elite_room_doors_show_the_elite_stats() -> void:
	# d2 = 2 puts the Elite Orc behind the left door.
	var door_choice: DoorChoice = _create(ELITE_ROOM, [2, 100])

	assert_has(_card_texts(door_choice, 0), "Elite Orc · AC 11 · HP 28 · Attack +7 · 1d10+2")
	assert_has(_card_texts(door_choice, 1), "Elite Skeleton · AC 13 · HP 18 · Attack +6 · 1d6+2")


func test_first_enter_button_has_focus() -> void:
	var door_choice: DoorChoice = _create(DOOR_ROOM, NO_REWARD_ROLLS)

	assert_true(_enter_button(door_choice, 0).has_focus())


func test_choosing_a_door_records_it_for_the_fight() -> void:
	var door_choice: DoorChoice = _create(DOOR_ROOM, NO_REWARD_ROLLS)
	var right_door: DoorOption = door_choice.doors()[1]

	door_choice.choose_door(right_door)

	assert_eq(RunState.chosen_door, right_door)
	assert_eq(RunState.create_room_enemies(), right_door.enemies)
	assert_true(_enter_button(door_choice, 0).disabled)
	assert_true(_enter_button(door_choice, 1).disabled)


# Entering also changes the scene, which would replace the running GUT scene, so only the target
# is checked.
func test_battle_scene_path_points_to_an_existing_scene() -> void:
	assert_true(ResourceLoader.exists(DoorChoice.BATTLE_SCENE_PATH, "PackedScene"))
