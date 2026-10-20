extends GutTest
## Battle scene: enemy cards, dice display and log show only what the revealed rolls proved.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
const GOBLIN_ID: StringName = &"goblin"
## The warrior hits Goblin 1 with 12 + 5 = 17 for 3 + 4 (1 HP left), both goblins miss.
const PLAIN_HIT_ROLLS: Array[int] = [12, 3, 2, 2]
## The warrior misses with 6 + 5 = 11, both goblins miss.
const MISS_ROLLS: Array[int] = [6, 2, 2]
## Round 1: 7 + 5 = 12 hits Goblin 1 narrowly for 1 + 4. Round 2: 6 + 5 = 11 misses it.
## Both goblins miss in both rounds.
const NARROW_HIT_THEN_MISS_ROLLS: Array[int] = [7, 1, 2, 2, 6, 2, 2]
## The warrior crits Goblin 1 for 3 + 2 + 4 and fells it, Goblin 2 misses.
const CRIT_ROLLS: Array[int] = [20, 3, 2, 2]
## The warrior fells Goblin 1 with 17 + 5 = 22 for 4 + 4, only Goblin 2 attacks and hits.
const ONE_GOBLIN_ATTACKS_ROLLS: Array[int] = [17, 4, 13, 4]
## The warrior hits Goblin 1 with 17 for 3 + 4, Goblin 1 hits for 4 + 1, Goblin 2 for 2 + 1.
const ROUND_ROLLS: Array[int] = [12, 3, 13, 4, 13, 2]
## Round 1 as PLAIN_HIT_ROLLS. Round 2: 10 + 5 = 15 fells Goblin 1, Goblin 2 misses.
const TWO_ROUND_ROLLS: Array[int] = [12, 3, 2, 2, 10, 1, 2]
## Generous upper bound. A round with three animated attacks plays back in about 3.3 seconds.
const PLAYBACK_TIMEOUT: float = 15.0


## Warrior: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP each.
func _start_battle(rolls: Array[int], animations_enabled: bool = false) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	return _open_battle(rolls, animations_enabled)


## Opens the next battle of the running run, as a later room would.
func _open_battle(rolls: Array[int], animations_enabled: bool = false) -> Battle:
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(animations_enabled)
	add_child_autofree(battle)
	return battle


func _attack(battle: Battle) -> void:
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	await battle.wait_for_playback()


# Polls with a timeout, so a broken playback fails the test instead of hanging the suite.
func _finish_playback(battle: Battle) -> void:
	var is_idle: Callable = func() -> bool: return not battle.is_playing_back()
	var finished: bool = await wait_until(is_idle, PLAYBACK_TIMEOUT)
	assert_true(finished, "Playback must finish")


func _wait_for_log(battle: Battle, text: String) -> void:
	var is_logged: Callable = func() -> bool: return _log_text(battle).contains(text)
	var logged: bool = await wait_until(is_logged, PLAYBACK_TIMEOUT)
	assert_true(logged, "Precondition: '%s' is logged" % text)


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


func _stats_text(card: CombatantCard) -> String:
	return (card.get_node("%StatsLabel") as Label).text


func _assert_enemy_cards_show(battle: Battle, stats_text: String, message: String = "") -> void:
	assert_eq(_stats_text(_enemy_card(battle, 0)), stats_text, "Goblin 1. " + message)
	assert_eq(_stats_text(_enemy_card(battle, 1)), stats_text, "Goblin 2. " + message)


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func _attack_line(attacker: Combatant, defender: Combatant) -> String:
	return "%s attacks %s" % [attacker.display_name, defender.display_name]


func test_enemy_cards_start_hidden() -> void:
	var battle: Battle = _start_battle([])

	_assert_enemy_cards_show(battle, "AC ?   Attack ?")
	assert_no_new_orphans()


func test_player_card_keeps_its_exact_stats() -> void:
	var battle: Battle = _start_battle(PLAIN_HIT_ROLLS)

	await _attack(battle)

	assert_eq(_stats_text(battle.get_node("%PlayerCard") as CombatantCard), "AC 14   Attack +5")
	assert_no_new_orphans()


func test_plain_hit_bounds_the_armor_class_on_every_card_of_the_type() -> void:
	var battle: Battle = _start_battle(PLAIN_HIT_ROLLS)

	await _attack(battle)

	_assert_enemy_cards_show(battle, "AC ≤ 15   Attack +3", "A plain hit with 17 is no narrow one")
	assert_no_new_orphans()


func test_miss_raises_the_lowest_armor_class() -> void:
	var battle: Battle = _start_battle(MISS_ROLLS)

	await _attack(battle)

	_assert_enemy_cards_show(battle, "AC ≥ 12   Attack +3", "11 missed")
	assert_no_new_orphans()


func test_narrow_hit_and_miss_reveal_the_exact_armor_class() -> void:
	var battle: Battle = _start_battle(NARROW_HIT_THEN_MISS_ROLLS)
	await _attack(battle)
	_assert_enemy_cards_show(battle, "AC 11–12   Attack +3", "Precondition: 12 hit narrowly")

	await _attack(battle)

	_assert_enemy_cards_show(battle, "AC 12   Attack +3", "11 missed")
	assert_no_new_orphans()


func test_natural_twenty_teaches_nothing_about_the_armor_class() -> void:
	var battle: Battle = _start_battle(CRIT_ROLLS)

	await _attack(battle)

	_assert_enemy_cards_show(battle, "AC ?   Attack +3")
	assert_no_new_orphans()


func test_enemy_attack_reveals_the_attack_bonus_on_every_card_of_the_type() -> void:
	var battle: Battle = _start_battle(ONE_GOBLIN_ATTACKS_ROLLS)

	await _attack(battle)

	assert_true(_enemy_card(battle, 0).is_defeated(), "Precondition: Goblin 1 never attacks")
	_assert_enemy_cards_show(battle, "AC ≤ 20   Attack +3", "Goblin 2's attack shows the bonus")
	assert_no_new_orphans()


func test_cards_learn_only_when_a_roll_is_revealed() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS, true)
	var goblin: Combatant = _enemy_card(battle, 0).combatant

	(battle.get_node("%AttackButton") as Button).pressed.emit()

	assert_eq(goblin.hit_points, 1, "Precondition: the whole round is resolved")
	assert_true(battle.is_playing_back(), "Precondition: the player's attack still rolls")
	assert_eq(
		RunState.enemy_knowledge.highest_armor_class(GOBLIN_ID),
		EnemyKnowledge.UNKNOWN,
		"Nothing is learned before the reveal"
	)
	_assert_enemy_cards_show(battle, "AC ?   Attack ?", "Nothing is revealed yet")
	await _wait_for_log(battle, _attack_line(RunState.player, goblin))
	_assert_enemy_cards_show(battle, "AC ≤ 15   Attack ?", "Only the player's attack is revealed")
	await _wait_for_log(battle, _attack_line(goblin, RunState.player))
	_assert_enemy_cards_show(battle, "AC ≤ 15   Attack +3", "Goblin 1's attack is revealed")
	battle.set_animations_enabled(false)
	await _finish_playback(battle)
	assert_no_new_orphans()


func test_knowledge_carries_into_the_next_battle_of_the_run() -> void:
	await _attack(_start_battle(PLAIN_HIT_ROLLS))

	var next_battle: Battle = _open_battle([])

	_assert_enemy_cards_show(next_battle, "AC ≤ 15   Attack +3")
	assert_no_new_orphans()


func test_new_run_forgets_the_knowledge() -> void:
	await _attack(_start_battle(PLAIN_HIT_ROLLS))

	var new_run_battle: Battle = _start_battle([])

	_assert_enemy_cards_show(new_run_battle, "AC ?   Attack ?")
	assert_no_new_orphans()


func test_dice_display_shows_the_armor_class_as_known_before_each_roll() -> void:
	var battle: Battle = _start_battle(TWO_ROUND_ROLLS)
	var dice_display: DiceDisplay = battle.get_node("%DiceDisplay") as DiceDisplay
	var detail_label: Label = dice_display.get_node("%DetailLabel") as Label
	var details: Array[String] = []
	dice_display.result_revealed.connect(
		func(_outcome: DiceDisplay.Outcome) -> void: details.append(detail_label.text)
	)

	await _attack(battle)
	await _attack(battle)

	var expected: Array[String] = [
		"+5 = 17 vs AC ?",
		"+3 = 5 vs AC 14",
		"+3 = 5 vs AC 14",
		"+5 = 15 vs AC ≤ 15",
		"+3 = 5 vs AC 14",
	]
	assert_eq(details, expected, "Attacks on the player show the exact AC")
	assert_no_new_orphans()


func test_log_shows_the_armor_class_as_known_before_each_roll() -> void:
	var battle: Battle = _start_battle(TWO_ROUND_ROLLS)

	await _attack(battle)
	await _attack(battle)

	var log_text: String = _log_text(battle)
	assert_string_contains(log_text, "Warrior attacks Goblin 1: d20 12 +5 = 17 vs AC ? - hit")
	assert_string_contains(log_text, "Warrior attacks Goblin 1: d20 10 +5 = 15 vs AC ≤ 15 - hit")
	assert_string_contains(log_text, "Goblin 2 attacks Warrior: d20 2 +3 = 5 vs AC 14 - miss.")
	assert_no_new_orphans()


func test_log_names_narrow_hits() -> void:
	var battle: Battle = _start_battle(NARROW_HIT_THEN_MISS_ROLLS)

	await _attack(battle)

	assert_string_contains(
		_log_text(battle), "d20 7 +5 = 12 vs AC ? - narrow hit, 5 damage (dice 1, bonus +4)."
	)
	assert_no_new_orphans()
