extends GutTest
## Battle scene: the way on after a fight and the character sheet.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
## The warrior fells Goblin 1, Goblin 2 misses, the warrior fells Goblin 2 in round 2.
const VICTORY_ROLLS: Array[int] = [17, 4, 2, 17, 4]
## The warrior misses, both goblins hit for 6 + 1, which takes all 14 HP.
const DEFEAT_ROLLS: Array[int] = [2, 13, 6, 13, 6]


func _start_battle(rolls: Array[int]) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)
	return battle


func _attack(battle: Battle) -> void:
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	await battle.wait_for_playback()


func _continue_button(battle: Battle) -> Button:
	return battle.get_node("%ContinueButton") as Button


func test_continue_is_hidden_during_the_fight() -> void:
	var battle: Battle = _start_battle([])

	assert_false(_continue_button(battle).visible)


func test_victory_offers_continue() -> void:
	var battle: Battle = _start_battle(VICTORY_ROLLS)

	await _attack(battle)
	await _attack(battle)

	assert_true(_continue_button(battle).visible)
	assert_false(_continue_button(battle).disabled)
	assert_true(_continue_button(battle).has_focus())


func test_defeat_offers_no_continue() -> void:
	var battle: Battle = _start_battle(DEFEAT_ROLLS)

	await _attack(battle)

	assert_false(_continue_button(battle).visible)


# The scene change itself would replace the running GUT scene, so only its target is checked.
func test_level_up_path_points_to_an_existing_scene() -> void:
	assert_true(ResourceLoader.exists(Battle.LEVEL_UP_SCENE_PATH, "PackedScene"))


func test_log_names_the_room() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.advance_room()
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)

	var log_text: String = (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()
	assert_string_contains(log_text, "Room 2")


func test_character_button_shows_the_player_on_the_sheet() -> void:
	var battle: Battle = _start_battle([])

	(battle.get_node("%CharacterButton") as Button).pressed.emit()

	var sheet: CharacterSheet = battle.get_node("%CharacterSheet") as CharacterSheet
	assert_true(sheet.visible)
	assert_eq(sheet.character, RunState.player)
	assert_eq(sheet.stat_text(StatSheet.ATTACK), "+5")
