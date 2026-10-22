extends GutTest
## Battle scene: victory and defeat states and Second Wind, which keeps the turn going.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SECOND_WIND: SkillData = preload("res://scripts/data/skills/second_wind.tres")
const SEED: int = 42
const SECOND_WIND_BUTTON: NodePath = ^"%SkillButtons/SecondWindButton"
## The warrior fells Goblin 1 and ends the turn with the Momentum of the kill, Goblin 2 misses,
## the warrior fells Goblin 2 in round 2.
const VICTORY_ROLLS: Array[int] = [17, 4, 2, 17, 4]
## The warrior misses, both goblins hit for 6 + 1, which takes all 14 HP.
const DEFEAT_ROLLS: Array[int] = [2, 13, 6, 13, 6]

var _dice: FixedDice


## Warrior: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP each.
func _start_battle(rolls: Array[int]) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	# Room 2 behind a door of two goblins, so the fight starts without a roll.
	RunState.advance_room()
	RunState.choose_door(GoblinPairDoor.create())
	_dice = FixedDice.new(rolls)
	RunState.dice = _dice
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)
	return battle


func _press(battle: Battle, button: Button) -> void:
	button.pressed.emit()
	await battle.wait_for_playback()


func _attack_button(battle: Battle) -> Button:
	return battle.get_node("%AttackButton") as Button


func _end_turn_button(battle: Battle) -> Button:
	return battle.get_node("%EndTurnButton") as Button


func _second_wind_button(battle: Battle) -> Button:
	return battle.get_node(SECOND_WIND_BUTTON) as Button


func _main_menu_button(battle: Battle) -> Button:
	return battle.get_node("%MainMenuButton") as Button


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


func _shown_player_hit_points(battle: Battle) -> int:
	var card: CombatantCard = battle.get_node("%PlayerCard") as CombatantCard
	return roundi((card.get_node("%HitPointBar") as ProgressBar).value)


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func _round_line_count(battle: Battle) -> int:
	var count: int = 0
	for line: String in _log_text(battle).split("\n"):
		if line.begins_with("Round "):
			count += 1
	return count


func _win(battle: Battle) -> void:
	await _press(battle, _attack_button(battle))
	await _press(battle, _end_turn_button(battle))
	await _press(battle, _attack_button(battle))


## The warrior misses, Goblin 1 hits for 4 + 1 (9 HP left), Goblin 2 misses. The heal rolls a 3.
func _start_wounded_battle(extra_rolls: Array[int]) -> Battle:
	var rolls: Array[int] = [2, 13, 4, 2, 3]
	rolls.append_array(extra_rolls)
	var battle: Battle = _start_battle(rolls)
	await _press(battle, _attack_button(battle))
	return battle


func test_victory_is_logged() -> void:
	var battle: Battle = _start_battle(VICTORY_ROLLS)

	await _win(battle)

	assert_string_contains(_log_text(battle), "Victory!")
	assert_no_new_orphans()


func test_victory_locks_the_actions_except_main_menu() -> void:
	var battle: Battle = _start_battle(VICTORY_ROLLS)

	await _win(battle)

	assert_true(_attack_button(battle).disabled, "Attack")
	assert_true(_second_wind_button(battle).disabled, "Second Wind")
	assert_false(_enemy_card(battle, 0).is_selectable(), "Goblin 1")
	assert_false(_enemy_card(battle, 1).is_selectable(), "Goblin 2")
	assert_false(_main_menu_button(battle).disabled, "Main Menu")
	assert_no_new_orphans()


func test_attack_press_after_victory_changes_nothing() -> void:
	var rolls: Array[int] = VICTORY_ROLLS.duplicate()
	rolls.append_array([17, 4])
	var battle: Battle = _start_battle(rolls)
	await _win(battle)
	var log_before: String = _log_text(battle)

	await _press(battle, _attack_button(battle))

	assert_eq(_dice.remaining_rolls(), 2, "No attack may be rolled after the fight")
	assert_eq(_log_text(battle), log_before, "Nothing may be logged after the fight")
	assert_no_new_orphans()


func test_skill_press_after_victory_changes_nothing() -> void:
	var rolls: Array[int] = VICTORY_ROLLS.duplicate()
	rolls.append(5)
	var battle: Battle = _start_battle(rolls)
	await _win(battle)
	var log_before: String = _log_text(battle)

	await _press(battle, _second_wind_button(battle))

	assert_eq(_dice.remaining_rolls(), 1, "No heal may be rolled after the fight")
	assert_eq(_log_text(battle), log_before, "Nothing may be logged after the fight")
	assert_no_new_orphans()


func test_defeat_is_logged() -> void:
	var battle: Battle = _start_battle(DEFEAT_ROLLS)

	await _press(battle, _attack_button(battle))

	assert_string_contains(_log_text(battle), "You have fallen")
	assert_no_new_orphans()


func test_defeat_locks_the_actions_except_main_menu() -> void:
	var battle: Battle = _start_battle(DEFEAT_ROLLS)

	await _press(battle, _attack_button(battle))

	assert_true(_attack_button(battle).disabled, "Attack")
	assert_true(_second_wind_button(battle).disabled, "Second Wind")
	assert_false(_enemy_card(battle, 0).is_selectable(), "Goblin 1")
	assert_false(_enemy_card(battle, 1).is_selectable(), "Goblin 2")
	assert_false(_main_menu_button(battle).disabled, "Main Menu")
	assert_no_new_orphans()


# The scene change itself would replace the running GUT scene, so only its target is checked.
func test_main_menu_path_points_to_an_existing_scene() -> void:
	assert_true(ResourceLoader.exists(Battle.MAIN_MENU_SCENE_PATH, "PackedScene"))


func test_each_active_skill_gets_one_button() -> void:
	var battle: Battle = _start_battle([])

	var buttons: Node = battle.get_node("%SkillButtons")
	assert_eq(buttons.get_child_count(), RunState.player.active_skills().size())
	assert_not_null(_second_wind_button(battle), "Second Wind is the warrior's active skill")
	assert_no_new_orphans()


func test_second_wind_heals_the_player_card() -> void:
	var battle: Battle = await _start_wounded_battle([])
	assert_eq(_shown_player_hit_points(battle), 9, "Precondition: 14 HP minus 5 damage")

	await _press(battle, _second_wind_button(battle))

	assert_eq(_shown_player_hit_points(battle), 13, "9 HP + 3 + level 1")
	assert_no_new_orphans()


func test_second_wind_does_not_start_a_new_round() -> void:
	# The last two rolls would be the goblins' attacks, if Second Wind ended the turn. It leaves
	# 2 of 3 Momentum, enough for another action.
	var battle: Battle = await _start_wounded_battle([2, 2])
	var round_lines_before: int = _round_line_count(battle)

	await _press(battle, _second_wind_button(battle))

	assert_eq(_round_line_count(battle), round_lines_before, "No new round line")
	assert_eq(_dice.remaining_rolls(), 2, "The goblins may not act after a free action")
	assert_no_new_orphans()


func test_second_wind_button_is_spent_after_use() -> void:
	var battle: Battle = await _start_wounded_battle([])

	await _press(battle, _second_wind_button(battle))

	var button: Button = _second_wind_button(battle)
	assert_true(button.disabled, "Second Wind works once per fight")
	assert_eq(button.text, "%s · 1  (0 left)" % SECOND_WIND.display_name, "Cost and 0 uses left")
	assert_no_new_orphans()


func test_attack_stays_enabled_after_second_wind() -> void:
	var battle: Battle = await _start_wounded_battle([])

	await _press(battle, _second_wind_button(battle))

	assert_false(_attack_button(battle).disabled, "Second Wind does not use the turn")
	assert_no_new_orphans()
