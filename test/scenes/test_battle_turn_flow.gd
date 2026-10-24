extends GutTest
## Battle scene: the central Momentum bar, the cost preview, the turn banners and End Turn's glow.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
## The warrior misses and has no Momentum left, both goblins miss.
const MISS_ROUND_ROLLS: Array[int] = [2, 2, 2]
## Both goblins miss.
const ENEMIES_MISS_ROLLS: Array[int] = [2, 2]


## Warrior: attack +5 vs AC 12, 14 HP, 2 Momentum. Goblins: attack +3 vs AC 14.
func _start_battle(rolls: Array[int]) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	# A room 2 fight node with two goblins, so the fight starts without a roll.
	RunState.enter_node(GoblinPairNode.create())
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)
	return battle


func _press(battle: Battle, button_name: String) -> void:
	(battle.get_node("%" + button_name) as Button).pressed.emit()
	await battle.wait_for_playback()


func _momentum_bar(battle: Battle) -> MomentumBar:
	return battle.get_node("%MomentumBar") as MomentumBar


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func test_player_momentum_shows_on_the_central_bar_instead_of_the_card() -> void:
	var battle: Battle = _start_battle([])

	assert_eq(_momentum_bar(battle).shown_momentum(), 2)
	var player_card: CombatantCard = battle.get_node("%PlayerCard") as CombatantCard
	assert_false((player_card.get_node("%MomentumRow") as Control).visible)


func test_hovering_an_action_previews_its_cost() -> void:
	var battle: Battle = _start_battle([])
	var attack_button: Button = battle.get_node("%AttackButton") as Button

	attack_button.mouse_entered.emit()
	assert_eq(_momentum_bar(battle).previewed_orbs(), 2)

	attack_button.mouse_exited.emit()
	assert_eq(_momentum_bar(battle).previewed_orbs(), 0)


func test_automatic_turn_end_is_announced_before_the_enemy_turn() -> void:
	var battle: Battle = _start_battle(MISS_ROUND_ROLLS)

	await _press(battle, "AttackButton")

	var log_text: String = _log_text(battle)
	assert_string_contains(log_text, Battle.OUT_OF_MOMENTUM_LOG)
	assert_true(
		log_text.find(Battle.OUT_OF_MOMENTUM_LOG) < log_text.find("Enemy turn"),
		"Out of Momentum comes first"
	)
	var banner: TurnBanner = battle.get_node("%TurnBanner") as TurnBanner
	assert_eq(banner.last_text(), TurnBanner.YOUR_TURN_TEXT, "Round 2 is the player's again")


func test_ending_the_turn_by_hand_needs_no_out_of_momentum_note() -> void:
	var battle: Battle = _start_battle(ENEMIES_MISS_ROLLS)

	await _press(battle, "EndTurnButton")

	var log_text: String = _log_text(battle)
	assert_string_contains(log_text, "Enemy turn")
	assert_false(log_text.contains(Battle.OUT_OF_MOMENTUM_LOG))


func test_end_turn_glows_once_an_attack_is_out_of_reach() -> void:
	var battle: Battle = _start_battle([])
	assert_false(battle.is_end_turn_highlighted(), "2 Momentum pay for an attack")

	await _press(battle, "BlockButton")

	assert_true(battle.is_end_turn_highlighted(), "1 Momentum left, Second Wind still possible")


func test_momentum_bar_names_the_last_gain() -> void:
	var battle: Battle = _start_battle(MISS_ROUND_ROLLS)

	await _press(battle, "AttackButton")

	var bar: MomentumBar = _momentum_bar(battle)
	assert_eq(bar.shown_momentum(), 4, "0 + 2 fended off + 2 for round 2")
	assert_eq(bar.change_text(), "+2 new round")
