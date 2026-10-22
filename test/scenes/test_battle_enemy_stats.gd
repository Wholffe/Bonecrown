extends GutTest
## Battle scene: enemy cards, dice display and log show the exact enemy stats from the start.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
## The warrior hits Goblin 1 with 12 + 5 = 17 for 3 + 4 (1 HP left), both goblins miss.
const PLAIN_HIT_ROLLS: Array[int] = [12, 3, 2, 2]
## 7 + 5 = 12 hits Goblin 1 narrowly for 1 + 4, both goblins miss.
const NARROW_HIT_ROLLS: Array[int] = [7, 1, 2, 2]


## Warrior: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP each.
func _start_battle(rolls: Array[int], animations_enabled: bool = false) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	# Room 2 behind a door of two goblins, so the fight starts without a roll.
	RunState.advance_room()
	RunState.choose_door(GoblinPairDoor.create())
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(animations_enabled)
	add_child_autofree(battle)
	return battle


func _attack(battle: Battle) -> void:
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	await battle.wait_for_playback()


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


func _stats_text(card: CombatantCard) -> String:
	return (card.get_node("%StatsLabel") as Label).text


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func test_enemy_cards_show_the_exact_stats_from_the_start() -> void:
	var battle: Battle = _start_battle(PLAIN_HIT_ROLLS)

	assert_eq(_stats_text(_enemy_card(battle, 0)), "AC 12   Attack +3", "Goblin 1")
	assert_eq(_stats_text(_enemy_card(battle, 1)), "AC 12   Attack +3", "Goblin 2")
	assert_no_new_orphans()


func test_player_card_shows_the_exact_stats() -> void:
	var battle: Battle = _start_battle(PLAIN_HIT_ROLLS)

	assert_eq(_stats_text(battle.get_node("%PlayerCard") as CombatantCard), "AC 14   Attack +5")
	assert_no_new_orphans()


func test_dice_display_shows_the_exact_armor_class() -> void:
	var battle: Battle = _start_battle(PLAIN_HIT_ROLLS)
	var dice_display: DiceDisplay = battle.get_node("%DiceDisplay") as DiceDisplay
	var detail_label: Label = dice_display.get_node("%DetailLabel") as Label
	var details: Array[String] = []
	dice_display.result_revealed.connect(
		func(_outcome: DiceDisplay.Outcome) -> void: details.append(detail_label.text)
	)

	await _attack(battle)

	assert_eq(details, ["+5 = 17 vs AC 12", "+3 = 5 vs AC 14", "+3 = 5 vs AC 14"])
	assert_no_new_orphans()


func test_log_shows_the_exact_armor_class() -> void:
	var battle: Battle = _start_battle(PLAIN_HIT_ROLLS)

	await _attack(battle)

	var log_text: String = _log_text(battle)
	assert_string_contains(log_text, "Warrior attacks Goblin 1: d20 12 +5 = 17 vs AC 12 - hit")
	assert_string_contains(log_text, "Goblin 2 attacks Warrior: d20 2 +3 = 5 vs AC 14 - miss.")
	assert_no_new_orphans()


func test_log_names_narrow_hits() -> void:
	var battle: Battle = _start_battle(NARROW_HIT_ROLLS)

	await _attack(battle)

	assert_string_contains(
		_log_text(battle), "d20 7 +5 = 12 vs AC 12 - narrow hit, 5 damage (dice 1, bonus +4)."
	)
	assert_no_new_orphans()
