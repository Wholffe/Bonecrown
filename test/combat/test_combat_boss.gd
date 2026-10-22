extends GutTest
## Boss phases in Combat: thresholds, new values and intents, summons and their fall with the boss.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const BOSS_HIT_POINTS: int = 30
const SECOND_PHASE_AT: int = 20
const THIRD_PHASE_AT: int = 10
const THIRD_PHASE_ARMOR_CLASS: int = 12

var _player: Character
var _dice: FixedDice
var _boss: Enemy


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_boss = Enemy.new(_boss_data())


## Warrior: attack +5, d8+4, 2 Momentum. Boss: AC 15, attack +4, Strike (1 attack), +1 Momentum.
## Phase 2 from 20 HP: Command (no attack, allies +1 Momentum) and a summoned goblin.
## Phase 3 from 10 HP: AC 12, Frenzy (2 attacks), no Momentum.
func _boss_data() -> BossData:
	var data: BossData = BossData.new()
	data.id = &"test_boss"
	data.display_name = "Boss"
	data.armor_class = 15
	data.max_hit_points = BOSS_HIT_POINTS
	data.attack_bonus = 4
	data.damage_die_count = 1
	data.damage_die_sides = 6
	data.damage_bonus = 1
	data.momentum_per_round = 1
	data.momentum_cap = 2
	data.intents = [_intent(&"strike", 1, 0)]
	var second: BossPhaseData = BossPhaseData.new()
	second.hit_points_at_most = SECOND_PHASE_AT
	second.announcement = "The boss calls for help!"
	second.momentum_per_round = 1
	second.momentum_cap = 2
	second.intents = [_intent(&"command", 0, 1)]
	second.summons = [GOBLIN]
	var third: BossPhaseData = BossPhaseData.new()
	third.hit_points_at_most = THIRD_PHASE_AT
	third.announcement = "The boss rages!"
	third.armor_class = THIRD_PHASE_ARMOR_CLASS
	third.intents = [_intent(&"frenzy", 2, 0)]
	data.phases = [second, third]
	return data


func _intent(id: StringName, attack_count: int, momentum_to_allies: int) -> EnemyIntentData:
	var intent: EnemyIntentData = EnemyIntentData.new()
	intent.id = id
	intent.display_name = id
	intent.attack_count = attack_count
	intent.momentum_to_allies = momentum_to_allies
	return intent


func _start_combat(rolls: Array[int]) -> Combat:
	_dice = FixedDice.new(rolls)
	var enemies: Array[Combatant] = [_boss]
	var combat: Combat = Combat.new(_player, enemies, _dice, GAME_RULES)
	watch_signals(combat)
	combat.start()
	return combat


func _summon(combat: Combat) -> Enemy:
	return combat.enemies[1] as Enemy


## The parameter asserts of GUT only look at the latest emission.
func _was_emitted_with(combat: Combat, signal_name: String, parameters: Array) -> bool:
	for index: int in get_signal_emit_count(combat, signal_name):
		if get_signal_parameters(combat, signal_name, index) == parameters:
			return true
	return false


func test_boss_keeps_its_first_phase_above_the_threshold() -> void:
	# Hit for 1 + 4 = 5 leaves 25 HP. The attack spends all Momentum, the boss misses.
	var combat: Combat = _start_combat([15, 1, 2])

	combat.player_attack(_boss)

	assert_signal_not_emitted(combat, "phase_started")
	assert_eq(_boss.current_phase(), null)
	assert_eq(_boss.get_armor_class(), 15)


func test_boss_enters_the_next_phase_at_its_threshold() -> void:
	# Hit for 6 + 4 = 10 leaves exactly 20 HP. The summoned goblin misses.
	var combat: Combat = _start_combat([15, 6, 2])

	combat.player_attack(_boss)

	var data: BossData = _boss.data as BossData
	assert_signal_emitted_with_parameters(combat, "phase_started", [_boss, data.phases[0]])
	assert_eq(_boss.current_phase(), data.phases[0])


func test_phase_summons_join_the_fight_and_act_in_the_same_round() -> void:
	var combat: Combat = _start_combat([15, 6, 2])

	combat.player_attack(_boss)

	assert_eq(combat.enemies.size(), 2)
	var summon: Enemy = _summon(combat)
	assert_eq(summon.data, GOBLIN)
	assert_eq(summon.summoner, _boss)
	assert_signal_emitted_with_parameters(combat, "enemy_summoned", [summon])
	assert_eq(_dice.remaining_rolls(), 0, "The goblin attacked, Command rolls nothing")


func test_intent_without_attacks_gives_allies_momentum() -> void:
	var combat: Combat = _start_combat([15, 6, 2])

	combat.player_attack(_boss)

	var summon: Enemy = _summon(combat)
	assert_true(
		_was_emitted_with(combat, "momentum_changed", [summon, 1, 1, Combat.MomentumReason.RALLIED])
	)
	assert_eq(_boss.intent.id, &"command", "The new round keeps the phase's intents")


func test_one_hit_can_reach_several_phases() -> void:
	_boss.hit_points = 21
	# Hit for 8 + 4 = 12 leaves 9 HP. Frenzy misses twice, the goblin misses.
	var combat: Combat = _start_combat([15, 8, 2, 2, 2])

	combat.player_attack(_boss)

	assert_signal_emit_count(combat, "phase_started", 2)
	assert_eq(_boss.get_armor_class(), THIRD_PHASE_ARMOR_CLASS)
	assert_eq(_boss.intent.id, &"frenzy")
	assert_eq(_dice.remaining_rolls(), 0)


func test_new_phase_clamps_momentum_to_its_cap() -> void:
	_boss.momentum = 2
	_boss.hit_points = THIRD_PHASE_AT

	_boss.enter_next_phase()
	_boss.enter_next_phase()

	assert_eq(_boss.momentum_cap(), 0)
	assert_eq(_boss.momentum, 0)


func test_enemy_without_phases_never_changes_phase() -> void:
	var goblin: Enemy = Enemy.new(GOBLIN)
	goblin.hit_points = 1

	assert_eq(goblin.enter_next_phase(), null)
	assert_eq(goblin.intents(), GOBLIN.intents)


func test_summons_fall_with_their_summoner_and_the_fight_ends() -> void:
	# Round 1 calls the goblin, which misses. Round 2: the warrior fells the weakened boss.
	var combat: Combat = _start_combat([15, 6, 2, 15, 6])
	combat.player_attack(_boss)
	_boss.hit_points = 5

	combat.player_attack(_boss)

	var summon: Enemy = _summon(combat)
	assert_false(summon.is_alive())
	assert_signal_emitted_with_parameters(combat, "combatant_defeated", [summon])
	assert_true(combat.is_over)
	assert_signal_emitted_with_parameters(combat, "combat_ended", [true])
