extends GutTest
## Battle scene: Focus button, advantage and disadvantage in the log and the dice display, and the
## roll mode tags on the cards.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const FOCUS: SkillData = preload("res://scripts/data/skills/focus.tres")
const SEED: int = 42
const FOCUS_BUTTON: NodePath = ^"%SkillButtons/FocusButton"
const OFF_BALANCE_LINE: String = "Natural 1 – Off-Balance: next attack with disadvantage"
## With Focus the warrior keeps 15 of 3 and 15, so 15 + 5 = 20 hits Goblin 1 for 1 + 4.
## Both goblins miss.
const FOCUSED_ROLLS: Array[int] = [3, 15, 1, 2, 2]
## The warrior rolls a natural 1, both goblins miss.
const NATURAL_ONE_ROLLS: Array[int] = [1, 2, 2]
## Round 1 as NATURAL_ONE_ROLLS. Round 2: disadvantage keeps 6 of 6 and 15, so 6 + 5 = 11
## misses. Both goblins miss.
const OFF_BALANCE_ROLLS: Array[int] = [1, 2, 2, 6, 15, 2, 2]
## The warrior misses, Goblin 1 rolls a natural 1, Goblin 2 misses.
const GOBLIN_NATURAL_ONE_ROLLS: Array[int] = [2, 1, 2]
## Round 1 as GOBLIN_NATURAL_ONE_ROLLS. Round 2: the warrior fells Goblin 1 with 17 + 5 = 22
## for 4 + 4, Goblin 2 misses.
const OFF_BALANCE_GOBLIN_FELLED_ROLLS: Array[int] = [2, 1, 2, 17, 4, 2]
## The warrior rolls a natural 1, both goblins hit for 6 + 1, which takes all 14 HP.
const NATURAL_ONE_DEFEAT_ROLLS: Array[int] = [1, 13, 6, 13, 6]


## Warrior with Focus: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP.
func _start_battle(rolls: Array[int]) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.player.learn_skill(FOCUS)
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)
	return battle


func _press(battle: Battle, button: Button) -> void:
	button.pressed.emit()
	await battle.wait_for_playback()


func _attack(battle: Battle) -> void:
	await _press(battle, battle.get_node("%AttackButton") as Button)


func _focus(battle: Battle) -> void:
	await _press(battle, _focus_button(battle))


func _focus_button(battle: Battle) -> Button:
	return battle.get_node(FOCUS_BUTTON) as Button


func _player_card(battle: Battle) -> CombatantCard:
	return battle.get_node("%PlayerCard") as CombatantCard


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


func _roll_mode_label(card: CombatantCard) -> Label:
	return card.get_node("%RollModeLabel") as Label


func _assert_tag(card: CombatantCard, text: String, message: String = "") -> void:
	var tag: Label = _roll_mode_label(card)
	assert_true(tag.visible, "Tagged. " + message)
	assert_eq(tag.text, text, message)


func _assert_no_tag(card: CombatantCard, message: String = "") -> void:
	assert_false(_roll_mode_label(card).visible, "Not tagged. " + message)


func _dice_display_node(battle: Battle, node_name: String) -> Control:
	return battle.get_node("%DiceDisplay").get_node("%" + node_name) as Control


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func test_learned_focus_gets_a_usable_button() -> void:
	var battle: Battle = _start_battle([])

	var button: Button = _focus_button(battle)

	assert_not_null(button, "Focus is an active skill")
	assert_false(button.disabled, "Focus can be used")
	assert_eq(button.text, "%s (1)" % FOCUS.display_name, "Once per fight")
	assert_no_new_orphans()


func test_focus_button_is_spent_after_use() -> void:
	var battle: Battle = _start_battle([])

	await _focus(battle)

	var button: Button = _focus_button(battle)
	assert_true(button.disabled, "Focus works once per fight")
	assert_eq(button.text, "%s (0)" % FOCUS.display_name, "The button shows 0 uses left")
	assert_false((battle.get_node("%AttackButton") as Button).disabled, "Focus is a free action")
	assert_no_new_orphans()


func test_focus_tags_the_player_card_with_advantage() -> void:
	var battle: Battle = _start_battle([])

	await _focus(battle)

	_assert_tag(_player_card(battle), "Advantage")
	_assert_no_tag(_enemy_card(battle, 0), "Goblin 1")
	_assert_no_tag(_enemy_card(battle, 1), "Goblin 2")
	assert_no_new_orphans()


func test_tag_is_gone_after_the_focused_attack() -> void:
	var battle: Battle = _start_battle(FOCUSED_ROLLS)
	await _focus(battle)

	await _attack(battle)

	_assert_no_tag(_player_card(battle))
	assert_no_new_orphans()


func test_advantage_roll_names_both_dice_in_the_log() -> void:
	var battle: Battle = _start_battle(FOCUSED_ROLLS)
	await _focus(battle)

	await _attack(battle)

	assert_string_contains(_log_text(battle), "d20 15 / 3 (advantage) +5 = 20 vs AC ? - hit,")
	assert_no_new_orphans()


func test_advantage_roll_shows_both_dice() -> void:
	var battle: Battle = _start_battle(FOCUSED_ROLLS)
	await _focus(battle)
	var attack_line: String = (
		"%s attacks %s"
		% [RunState.player.display_name, _enemy_card(battle, 0).combatant.display_name]
	)
	var dice_texts: Array[String] = []
	# The goblins roll after the warrior, so the dice display is read when the attack is revealed.
	var display: DiceDisplay = battle.get_node("%DiceDisplay") as DiceDisplay
	display.result_revealed.connect(
		func(_outcome: DiceDisplay.Outcome) -> void:
			if (_dice_display_node(battle, "TitleLabel") as Label).text == attack_line:
				dice_texts.append((_dice_display_node(battle, "DieLabel") as Label).text)
				dice_texts.append((_dice_display_node(battle, "DiscardedDieLabel") as Label).text)
				dice_texts.append((_dice_display_node(battle, "RollModeLabel") as Label).text)
	)

	await _attack(battle)

	assert_eq(dice_texts, ["15", "3", "Advantage"] as Array[String], "Kept die, discarded die, tag")
	assert_no_new_orphans()


func test_natural_one_logs_off_balance_after_the_attack() -> void:
	var battle: Battle = _start_battle(NATURAL_ONE_ROLLS)

	await _attack(battle)

	var log_text: String = _log_text(battle)
	var attack_index: int = log_text.find("natural 1, automatic miss.")
	assert_gt(attack_index, -1, "Precondition: the natural 1 is logged")
	assert_gt(log_text.find(OFF_BALANCE_LINE), attack_index, "Off-Balance follows the attack")
	assert_no_new_orphans()


func test_natural_one_tags_the_player_card_with_disadvantage() -> void:
	var battle: Battle = _start_battle(NATURAL_ONE_ROLLS)

	await _attack(battle)

	_assert_tag(_player_card(battle), "Disadvantage")
	assert_no_new_orphans()


func test_disadvantage_roll_names_both_dice_in_the_log() -> void:
	var battle: Battle = _start_battle(OFF_BALANCE_ROLLS)
	await _attack(battle)

	await _attack(battle)

	assert_string_contains(_log_text(battle), "d20 6 / 15 (disadvantage) +5 = 11 vs AC ? - miss.")
	_assert_no_tag(_player_card(battle), "Off-Balance lasts for one attack")
	assert_no_new_orphans()


func test_focus_while_off_balance_shows_no_tag() -> void:
	var battle: Battle = _start_battle(NATURAL_ONE_ROLLS)
	await _attack(battle)

	await _focus(battle)

	_assert_no_tag(_player_card(battle), "Advantage and disadvantage cancel out")
	assert_no_new_orphans()


func test_enemy_natural_one_tags_only_its_card() -> void:
	var battle: Battle = _start_battle(GOBLIN_NATURAL_ONE_ROLLS)

	await _attack(battle)

	assert_string_contains(_log_text(battle), OFF_BALANCE_LINE)
	_assert_tag(_enemy_card(battle, 0), "Disadvantage", "Goblin 1")
	_assert_no_tag(_enemy_card(battle, 1), "Goblin 2")
	_assert_no_tag(_player_card(battle), "Warrior")
	assert_no_new_orphans()


func test_defeated_enemy_loses_its_tag() -> void:
	var battle: Battle = _start_battle(OFF_BALANCE_GOBLIN_FELLED_ROLLS)
	await _attack(battle)

	await _attack(battle)

	assert_true(_enemy_card(battle, 0).is_defeated(), "Precondition: Goblin 1 is felled")
	_assert_no_tag(_enemy_card(battle, 0), "A felled enemy never attacks again")
	assert_no_new_orphans()


func test_tags_are_gone_when_the_fight_ends() -> void:
	var battle: Battle = _start_battle(NATURAL_ONE_DEFEAT_ROLLS)

	await _attack(battle)

	assert_string_contains(_log_text(battle), "You have fallen")
	_assert_no_tag(_player_card(battle), "Off-Balance ends with the fight")
	assert_no_new_orphans()
