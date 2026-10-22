extends GutTest
## Battle scene: the way on after a fight, the character sheet and the equipment strip.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
## The warrior fells Goblin 1 and ends the turn, Goblin 2 misses, the warrior fells Goblin 2 in
## round 2.
const VICTORY_ROLLS: Array[int] = [17, 4, 2, 17, 4]
## The warrior misses, both goblins hit for 6 + 1, which takes all 14 HP.
const DEFEAT_ROLLS: Array[int] = [2, 13, 6, 13, 6]


func _start_battle(rolls: Array[int]) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	# Room 2 holds two goblins and picks them without a roll.
	RunState.advance_room()
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
	(battle.get_node("%EndTurnButton") as Button).pressed.emit()
	await battle.wait_for_playback()
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


func test_equipment_strip_shows_every_slot_without_captions() -> void:
	var battle: Battle = _start_battle([])

	var strip: Node = battle.get_node("%EquipmentStrip")
	assert_eq(strip.get_child_count(), PaperDoll.SLOT_SIDES.size())
	for child: Node in strip.get_children():
		var item_slot: ItemSlot = child as ItemSlot
		assert_eq(item_slot.item, RunState.player.item_in_slot(item_slot.slot))
		assert_false((item_slot.get_node("%CaptionLabel") as Label).visible, "Icons only")


func test_clicking_the_equipment_strip_opens_the_sheet() -> void:
	var battle: Battle = _start_battle([])
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	(battle.get_node("%EquipmentStrip").get_child(0) as ItemSlot)._gui_input(click)

	assert_true((battle.get_node("%CharacterSheet") as CharacterSheet).visible)
