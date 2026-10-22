extends GutTest
## Enemy Momentum and intents in Combat: gain, choice, cost and the effects of each intent field.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")

var _player: Character
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)


## Warrior: attack +5, AC 14, d8+4, 14 HP, 2 Momentum. Goblin: attack +3, AC 12, d6+1, 8 HP,
## +1 Momentum per round up to 3, Stab (free, 1 attack) and Frenzy (3 Momentum, 2 attacks).
func _start_combat(rolls: Array[int], enemies: Array[Combatant]) -> Combat:
	_dice = FixedDice.new(rolls)
	var combat: Combat = Combat.new(_player, enemies, _dice, GAME_RULES)
	watch_signals(combat)
	combat.start()
	return combat


## A goblin whose only intent is the given one, so it uses it every round.
func _enemy_with_intent(intent: EnemyIntentData) -> Enemy:
	var data: EnemyData = GOBLIN.duplicate()
	var intents: Array[EnemyIntentData] = [intent]
	data.intents = intents
	return Enemy.new(data)


func _intent(attack_count: int) -> EnemyIntentData:
	var intent: EnemyIntentData = EnemyIntentData.new()
	intent.id = &"test_intent"
	intent.display_name = "Test"
	intent.attack_count = attack_count
	return intent


func test_enemies_gain_momentum_and_announce_an_intent_each_round() -> void:
	var goblin: Enemy = Enemy.new(GOBLIN)
	var combat: Combat = _start_combat([], [goblin])

	assert_eq(goblin.momentum, 1, "0 at the start, +1 for round 1")
	assert_eq(goblin.intent.id, &"stab", "Frenzy costs 3")
	assert_signal_emitted(combat, "intents_announced")


func test_enemy_uses_the_most_expensive_intent_it_can_pay() -> void:
	var goblin: Enemy = Enemy.new(GOBLIN)
	var combat: Combat = _start_combat([2, 2, 2, 2], [goblin])
	combat.end_turn()

	combat.end_turn()

	assert_eq(combat.round_number, 3)
	assert_eq(goblin.momentum, 3)
	assert_eq(goblin.intent.id, &"frenzy")


func test_intent_spends_its_momentum_and_attacks_as_often_as_it_says() -> void:
	var goblin: Enemy = Enemy.new(GOBLIN)
	var combat: Combat = _start_combat([2, 2, 2, 2], [goblin])
	combat.end_turn()
	combat.end_turn()

	combat.end_turn()

	assert_eq(_dice.remaining_rolls(), 0, "Stab, Stab, then two Frenzy attacks")
	assert_signal_emitted_with_parameters(combat, "intent_started", [goblin, GOBLIN.intents[1]])
	assert_eq(goblin.momentum, 1, "3 - 3 for Frenzy, +1 for round 4")


func test_enemy_momentum_stops_at_its_cap() -> void:
	var goblin: Enemy = Enemy.new(GOBLIN)
	goblin.momentum = 3
	_start_combat([], [goblin])

	assert_eq(goblin.momentum, 3, "The cap is 3")


func test_extra_damage_dice_add_to_every_hit() -> void:
	var intent: EnemyIntentData = _intent(1)
	intent.extra_damage_dice = 1
	var enemy: Enemy = _enemy_with_intent(intent)
	var combat: Combat = _start_combat([15, 3, 4], [enemy])

	combat.end_turn()

	assert_eq(_player.hit_points, 6, "15 + 3 hits AC 14, 2d6 + 1 = 3 + 4 + 1")


func test_momentum_drain_takes_momentum_from_the_player_on_a_hit() -> void:
	var intent: EnemyIntentData = _intent(1)
	intent.momentum_drain = 1
	var enemy: Enemy = _enemy_with_intent(intent)
	var combat: Combat = _start_combat([15, 3], [enemy])

	combat.end_turn()

	assert_eq(_player.momentum, 3, "2 - 1 for the drain, +2 for round 2")


func test_momentum_to_allies_feeds_every_other_living_enemy() -> void:
	var intent: EnemyIntentData = _intent(1)
	intent.momentum_to_allies = 2
	var rallier: Enemy = _enemy_with_intent(intent)
	var ally: Enemy = Enemy.new(GOBLIN)
	var combat: Combat = _start_combat([2, 2], [rallier, ally])

	combat.end_turn()

	assert_eq(ally.momentum, 3, "1 + 2 from the rally capped at 3, +1 for round 2 stays capped")
	assert_eq(rallier.momentum, 2, "It gives Momentum only to others")
	assert_eq(ally.intent.id, &"frenzy")
