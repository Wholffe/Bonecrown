extends GutTest
## Battle scene: Momentum pips, Block, End Turn, enemy intents and the character sheet lock.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
## The warrior misses Goblin 1, both goblins miss.
const ALL_MISS_ROLLS: Array[int] = [2, 2, 2]
## Both goblins miss in rounds 1 and 2, the player only ends the turn.
const TWO_QUIET_ROUNDS_ROLLS: Array[int] = [2, 2, 2, 2]
## Block: each goblin rolls two d20 and keeps the lower one, all miss.
const BLOCKED_ROLLS: Array[int] = [15, 2, 15, 2]
const PLAYBACK_TIMEOUT: float = 15.0

var _dice: FixedDice


## Warrior: attack +5 vs AC 12, d8+4, 14 HP, 2 of 4 Momentum. Goblins: attack +3 vs AC 14,
## d6+1, 8 HP, 1 of 3 Momentum in round 1, Stab or Frenzy (3 Momentum, two attacks).
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


func _press(battle: Battle, button_name: String) -> void:
	(battle.get_node("%" + button_name) as Button).pressed.emit()
	await battle.wait_for_playback()


func _button(battle: Battle, button_name: String) -> Button:
	return battle.get_node("%" + button_name) as Button


func _player_card(battle: Battle) -> CombatantCard:
	return battle.get_node("%PlayerCard") as CombatantCard


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func test_cards_show_the_momentum_at_the_start() -> void:
	var battle: Battle = _start_battle([])

	assert_eq(_player_card(battle).shown_momentum(), 2, "Player")
	assert_eq(_enemy_card(battle, 0).shown_momentum(), 1, "Goblin 1")
	assert_no_new_orphans()


func test_enemy_cards_announce_their_intent() -> void:
	var battle: Battle = _start_battle([])

	assert_eq(_enemy_card(battle, 0).intent_text(), "Next: Stab: 1d6+1")
	assert_eq(_enemy_card(battle, 1).intent_text(), "Next: Stab: 1d6+1")
	assert_no_new_orphans()


func test_frenzy_is_announced_and_logged() -> void:
	var battle: Battle = _start_battle([2, 2, 2, 2, 2, 2, 2, 2])
	await _press(battle, "EndTurnButton")
	await _press(battle, "EndTurnButton")
	assert_eq(_enemy_card(battle, 0).intent_text(), "Next: Frenzy: 2× 1d6+1", "Round 3")

	await _press(battle, "EndTurnButton")

	assert_string_contains(_log_text(battle), "Goblin 1 uses Frenzy.")
	assert_eq(_dice.remaining_rolls(), 0, "Two Frenzy attacks per goblin")
	assert_no_new_orphans()


func test_attack_and_misses_update_the_player_pips() -> void:
	var battle: Battle = _start_battle(ALL_MISS_ROLLS)

	await _press(battle, "AttackButton")

	assert_eq(_player_card(battle).shown_momentum(), 4, "0 + 2 fended off + 2 for round 2")
	assert_string_contains(_log_text(battle), "Warrior +1 Momentum (attack fended off)")
	assert_no_new_orphans()


func test_action_buttons_show_their_costs() -> void:
	var battle: Battle = _start_battle([])

	assert_eq(_button(battle, "AttackButton").text, "Attack · 2")
	assert_eq(_button(battle, "BlockButton").text, "Block · 1")
	assert_eq(_button(battle, "EndTurnButton").text, "End Turn")
	assert_no_new_orphans()


func test_block_is_logged_and_tags_the_enemies() -> void:
	var battle: Battle = _start_battle(BLOCKED_ROLLS)

	await _press(battle, "BlockButton")

	assert_string_contains(_log_text(battle), "Warrior blocks")
	assert_true(_button(battle, "BlockButton").disabled, "Once per turn")
	assert_true(_button(battle, "AttackButton").disabled, "1 Momentum left")
	assert_eq(_dice.remaining_rolls(), 4, "The turn goes on until End Turn")
	assert_no_new_orphans()


func test_blocked_enemy_attacks_roll_with_disadvantage() -> void:
	var battle: Battle = _start_battle(BLOCKED_ROLLS)
	await _press(battle, "BlockButton")

	await _press(battle, "EndTurnButton")

	assert_string_contains(_log_text(battle), "Goblin 1 attacks Warrior: d20 2 / 15 (disadvantage)")
	assert_true(_log_text(battle).contains("Round 2"), "End Turn starts the next round")
	assert_no_new_orphans()


func test_end_turn_keeps_the_momentum() -> void:
	var battle: Battle = _start_battle(TWO_QUIET_ROUNDS_ROLLS)

	await _press(battle, "EndTurnButton")

	assert_eq(_player_card(battle).shown_momentum(), 4, "2 kept + 2 fended off + 2, capped")
	assert_no_new_orphans()


func test_open_character_sheet_blocks_the_actions() -> void:
	var battle: Battle = _start_battle(ALL_MISS_ROLLS)
	var sheet: CharacterSheet = battle.get_node("%CharacterSheet") as CharacterSheet
	sheet.open()

	await _press(battle, "AttackButton")

	assert_eq(_dice.remaining_rolls(), 3, "Keys and presses must not reach the battle")
	assert_true(_button(battle, "AttackButton").disabled)
	sheet.hide()
	assert_false(_button(battle, "AttackButton").disabled, "Closing the sheet frees the actions")
	assert_no_new_orphans()


func test_character_sheet_cannot_open_during_playback() -> void:
	var battle: Battle = _start_battle(ALL_MISS_ROLLS)
	battle.set_animations_enabled(true)
	var sheet: CharacterSheet = battle.get_node("%CharacterSheet") as CharacterSheet
	_button(battle, "AttackButton").pressed.emit()
	assert_true(battle.is_playing_back(), "Precondition: the turn plays back")

	sheet.open()

	assert_false(sheet.visible, "It would show the hit points after the turn")
	var is_idle: Callable = func() -> bool: return not battle.is_playing_back()
	assert_true(await wait_until(is_idle, PLAYBACK_TIMEOUT), "Playback must finish")
	assert_no_new_orphans()
