extends GutTest
## Skill effects of the skill tree in Combat: attack skills, area damage, Momentum gain for hit
## points, counters while blocking and the Momentum modifier stats.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const SKELETON: EnemyData = preload("res://scripts/data/enemies/skeleton.tres")

var _player: Character
var _goblin: Enemy
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_goblin = Enemy.new(GOBLIN)


## Warrior: attack +5, AC 14, d8+4, 14 HP. Goblin: attack +3, AC 12, d6+1, 8 HP, +1 Momentum per
## round, Stab (free) or Frenzy (3). Momentum: 2 at the start, cap 4, Attack 2, Block 1.
func _start_combat(rolls: Array[int], enemies: Array[Combatant] = [_goblin]) -> Combat:
	_dice = FixedDice.new(rolls)
	var combat: Combat = Combat.new(_player, enemies, _dice, GAME_RULES)
	watch_signals(combat)
	combat.start()
	return combat


## A free active skill without a use limit keeps the turn going, so no enemy rolls are needed.
func _learn_active(effect: EffectData, momentum_cost: int = 0) -> SkillData:
	var skill: SkillData = SkillData.new()
	skill.id = &"test_active"
	skill.display_name = "Test Active"
	skill.activation = SkillData.Activation.ACTIVE
	skill.momentum_cost = momentum_cost
	skill.effects = [effect]
	_player.learn_skill(skill)
	return skill


func _learn_passive(effect: EffectData) -> SkillData:
	var skill: SkillData = SkillData.new()
	skill.id = &"test_passive"
	skill.activation = SkillData.Activation.PASSIVE
	skill.effects = [effect]
	_player.learn_skill(skill)
	return skill


func _modifier(stat: StatModifierEffect.Stat, amount: int) -> StatModifierEffect:
	var modifier: StatModifierEffect = StatModifierEffect.new()
	modifier.stat = stat
	modifier.amount = amount
	return modifier


func _area(die_count: int, die_sides: int) -> AreaDamageEffect:
	var area: AreaDamageEffect = AreaDamageEffect.new()
	area.die_count = die_count
	area.die_sides = die_sides
	return area


func _retaliate(die_count: int, die_sides: int) -> RetaliateEffect:
	var retaliate: RetaliateEffect = RetaliateEffect.new()
	retaliate.die_count = die_count
	retaliate.die_sides = die_sides
	return retaliate


func test_area_damage_hits_every_living_enemy_with_one_roll() -> void:
	var second_goblin: Enemy = Enemy.new(GOBLIN)
	var skill: SkillData = _learn_active(_area(2, 6))
	var combat: Combat = _start_combat([3, 4], [_goblin, second_goblin])

	combat.use_skill(skill)

	assert_eq(_goblin.hit_points, 1)
	assert_eq(second_goblin.hit_points, 1)
	var params: Array = get_signal_parameters(combat, "effect_damage_dealt")
	assert_eq(params[0], skill)
	assert_eq((params[1] as DamageRoll).total, 7)
	assert_eq(params[2], 6, "die sides")
	assert_eq(params[3], [_goblin, second_goblin] as Array[Combatant])
	assert_signal_not_emitted(combat, "attack_resolved")


func test_area_damage_kills_give_momentum_and_can_win_the_fight() -> void:
	var skill: SkillData = _learn_active(_area(2, 6))
	var combat: Combat = _start_combat([4, 4])

	combat.use_skill(skill)

	assert_signal_emitted_with_parameters(combat, "combatant_defeated", [_goblin])
	assert_eq(_player.momentum, 3, "2 at the start, +1 for the kill")
	assert_signal_emitted_with_parameters(combat, "combat_ended", [true])


func test_area_damage_reports_a_summon_and_its_summoner_once_each() -> void:
	var summon: Enemy = Enemy.new(SKELETON)
	summon.summoner = _goblin
	var skill: SkillData = _learn_active(_area(4, 6))
	var combat: Combat = _start_combat([6, 6, 6, 6], [_goblin, summon])

	combat.use_skill(skill)

	assert_signal_emit_count(combat, "combatant_defeated", 2)
	assert_eq(_player.momentum, 4, "+1 per kill, up to the cap")


func test_attack_effect_changes_the_attack_bonus_and_adds_damage_dice() -> void:
	var blow: AttackEffect = AttackEffect.new()
	blow.attack_bonus = -4
	blow.extra_damage_dice = 1
	var skill: SkillData = _learn_active(blow)
	var combat: Combat = _start_combat([15, 1, 1])

	combat.use_skill(skill, _goblin)

	var params: Array = get_signal_parameters(combat, "attack_resolved")
	assert_eq((params[2] as AttackRoll).attack_bonus, 1)
	assert_eq((params[3] as DamageRoll).dice_results.size(), 2)
	assert_eq(_goblin.hit_points, 2, "1 + 1 + 4 damage")


func test_attack_effect_splashes_the_other_enemies_on_a_hit() -> void:
	var second_goblin: Enemy = Enemy.new(GOBLIN)
	var strike: AttackEffect = AttackEffect.new()
	strike.splash_die_count = 1
	strike.splash_die_sides = 6
	var skill: SkillData = _learn_active(strike)
	var combat: Combat = _start_combat([15, 1, 5], [_goblin, second_goblin])

	combat.use_skill(skill, _goblin)

	assert_eq(_goblin.hit_points, 3, "only the attack's 1 + 4")
	assert_eq(second_goblin.hit_points, 3, "the splash's 5")
	assert_eq(
		get_signal_parameters(combat, "effect_damage_dealt")[3], [second_goblin] as Array[Combatant]
	)


func test_attack_effect_does_not_splash_on_a_miss() -> void:
	var second_goblin: Enemy = Enemy.new(GOBLIN)
	var strike: AttackEffect = AttackEffect.new()
	strike.splash_die_count = 1
	strike.splash_die_sides = 6
	var skill: SkillData = _learn_active(strike)
	var combat: Combat = _start_combat([2], [_goblin, second_goblin])

	combat.use_skill(skill, _goblin)

	assert_signal_not_emitted(combat, "effect_damage_dealt")
	assert_eq(second_goblin.hit_points, 8)


func test_momentum_drain_on_a_hit_makes_the_target_choose_an_affordable_intent() -> void:
	_goblin.momentum = 2
	var bash: AttackEffect = AttackEffect.new()
	bash.momentum_drain = 2
	var skill: SkillData = _learn_active(bash)
	var combat: Combat = _start_combat([15, 1])
	assert_eq(_goblin.intent.id, &"frenzy", "3 Momentum at the round start pays for Frenzy")

	combat.use_skill(skill, _goblin)

	assert_eq(_goblin.momentum, 1)
	assert_eq(_goblin.intent.id, &"stab")
	assert_signal_emit_count(combat, "intents_announced", 2)


func test_momentum_gain_pays_hit_points() -> void:
	var rage: MomentumGainEffect = MomentumGainEffect.new()
	rage.amount = 2
	rage.hit_point_cost = 6
	var skill: SkillData = _learn_active(rage)
	var combat: Combat = _start_combat([])

	combat.use_skill(skill)

	assert_eq(_player.hit_points, 8)
	assert_eq(_player.momentum, 4)
	assert_signal_emitted_with_parameters(combat, "hit_points_paid", [_player, 6, skill])


func test_momentum_gain_needs_more_hit_points_than_it_costs() -> void:
	var rage: MomentumGainEffect = MomentumGainEffect.new()
	rage.amount = 2
	rage.hit_point_cost = 6
	var skill: SkillData = _learn_active(rage)
	var combat: Combat = _start_combat([])
	_player.take_damage(8)

	assert_false(combat.can_use_skill(skill))


func test_a_miss_while_blocking_triggers_the_counter() -> void:
	var counter: SkillData = _learn_passive(_retaliate(1, 6))
	var combat: Combat = _start_combat([2, 3, 4])

	combat.player_block()
	combat.end_turn()

	assert_eq(_goblin.hit_points, 4)
	var params: Array = get_signal_parameters(combat, "effect_damage_dealt")
	assert_eq(params[0], counter)
	assert_eq(params[3], [_goblin] as Array[Combatant])


func test_no_counter_without_a_block() -> void:
	_learn_passive(_retaliate(1, 6))
	var combat: Combat = _start_combat([2])

	combat.end_turn()

	assert_signal_not_emitted(combat, "effect_damage_dealt")
	assert_eq(_goblin.hit_points, 8)


func test_a_counter_that_defeats_the_last_enemy_wins_the_fight() -> void:
	_learn_passive(_retaliate(1, 6))
	_goblin.hit_points = 3
	var combat: Combat = _start_combat([2, 3, 4])

	combat.player_block()
	combat.end_turn()

	assert_signal_emitted_with_parameters(combat, "combat_ended", [true])
	assert_signal_emit_count(combat, "round_started", 1, "no new round after the win")


func test_momentum_stats_raise_the_cap_and_the_starting_momentum() -> void:
	_learn_passive(_modifier(StatModifierEffect.Stat.MOMENTUM_CAP, 2))
	_learn_passive(_modifier(StatModifierEffect.Stat.MOMENTUM_AT_FIGHT_START, 1))
	var combat: Combat = _start_combat([])

	assert_eq(combat.momentum_cap_of(_player), 6)
	assert_eq(combat.momentum_cap_of(_goblin), 3)
	assert_eq(_player.momentum, 3)


func test_momentum_stats_add_to_kills_and_fended_off_attacks() -> void:
	_learn_passive(_modifier(StatModifierEffect.Stat.MOMENTUM_PER_KILL, 1))
	_learn_passive(_modifier(StatModifierEffect.Stat.MOMENTUM_PER_FENDED_ATTACK, 1))
	var second_goblin: Enemy = Enemy.new(GOBLIN)
	_goblin.hit_points = 1
	var combat: Combat = _start_combat([15, 1, 2], [_goblin, second_goblin])

	combat.player_attack(_goblin)
	assert_eq(_player.momentum, 2, "2 - 2 for the attack + 2 for the kill")
	combat.end_turn()

	assert_eq(_player.momentum, 4, "+2 for the fended-off attack, the new round is capped")


func test_conditional_attack_cost_applies_at_half_hit_points() -> void:
	var unstoppable: ConditionalModifierEffect = ConditionalModifierEffect.new()
	unstoppable.stat = StatModifierEffect.Stat.ATTACK_MOMENTUM_COST
	unstoppable.amount = -1
	unstoppable.condition = ConditionalModifierEffect.Condition.OWN_HP_AT_MOST_HALF
	_learn_passive(unstoppable)
	var combat: Combat = _start_combat([2])
	assert_eq(combat.attack_cost(), 2)

	_player.take_damage(7)
	combat.player_attack(_goblin)

	assert_eq(combat.attack_cost(), 1)
	assert_eq(_player.momentum, 1)


func test_free_block_can_be_used_once_per_turn() -> void:
	_learn_passive(_modifier(StatModifierEffect.Stat.BLOCK_MOMENTUM_COST, -1))
	var combat: Combat = _start_combat([])
	assert_eq(combat.block_cost(), 0)

	combat.player_block()

	assert_eq(_player.momentum, 2)
	assert_false(combat.can_block())
