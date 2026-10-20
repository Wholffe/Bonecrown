extends GutTest
## Skill rules of Combat: turn cost, availability, uses per fight, healing and skill signals.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const SECOND_WIND: SkillData = preload("res://scripts/data/skills/second_wind.tres")
const WEAPON_MASTER: SkillData = preload("res://scripts/data/skills/weapon_master.tres")
## SkillData.uses_per_fight value for a skill without a use limit.
const NO_USE_LIMIT: int = 0

var _player: Character
var _goblin: Enemy
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_goblin = Enemy.new(GOBLIN)


## Warrior: attack +5, AC 14, d8+4, 14 HP, level 1. Goblin: attack +3, AC 12, d6+1, 8 HP.
func _start_combat(rolls: Array[int]) -> Combat:
	_dice = FixedDice.new(rolls)
	var enemies: Array[Combatant] = [_goblin]
	var combat: Combat = Combat.new(_player, enemies, _dice)
	watch_signals(combat)
	combat.start()
	return combat


## Active skill that heals 1d4 without the level bonus.
func _healing_skill(action_cost: SkillData.ActionCost, uses_per_fight: int) -> SkillData:
	var heal: HealEffect = HealEffect.new()
	heal.die_count = 1
	heal.die_sides = 4
	var skill: SkillData = SkillData.new()
	skill.id = &"test_heal"
	skill.activation = SkillData.Activation.ACTIVE
	skill.action_cost = action_cost
	skill.uses_per_fight = uses_per_fight
	skill.effects = [heal]
	return skill


## Records the order of the skill and heal signals, which watch_signals() does not keep.
func _record_skill_signal_order(combat: Combat) -> Array[StringName]:
	var order: Array[StringName] = []
	combat.skill_used.connect(
		func(_user: Combatant, _skill: SkillData) -> void: order.append(&"skill_used")
	)
	combat.combatant_healed.connect(
		func(_combatant: Combatant, _heal: HealRoll, _restored: int, _skill: SkillData) -> void:
			order.append(&"combatant_healed")
	)
	return order


func test_second_wind_does_not_use_the_turn() -> void:
	var combat: Combat = _start_combat([7])

	combat.use_skill(SECOND_WIND)

	assert_eq(_dice.remaining_rolls(), 0, "The goblin must not act after a free skill")
	assert_eq(combat.round_number, 1)


func test_free_skill_and_attack_share_one_round() -> void:
	var combat: Combat = _start_combat([7, 2, 2])

	combat.use_skill(SECOND_WIND)
	combat.player_attack(_goblin)

	assert_eq(_dice.remaining_rolls(), 0, "Heal, player attack and one goblin attack")
	assert_signal_emit_count(combat, "attack_resolved", 2, "Exactly one goblin turn")
	assert_eq(combat.round_number, 2)


func test_free_skill_that_leaves_no_living_enemy_wins_the_fight() -> void:
	var combat: Combat = _start_combat([7])
	# No free skill damages enemies yet, so the goblin is defeated directly.
	_goblin.take_damage(_goblin.max_hit_points)

	combat.use_skill(SECOND_WIND)

	assert_true(combat.is_over)
	assert_signal_emitted_with_parameters(combat, "combat_ended", [true])


func test_action_skill_ends_the_turn() -> void:
	var skill: SkillData = _healing_skill(SkillData.ActionCost.ACTION, NO_USE_LIMIT)
	_player.skills.append(skill)
	var combat: Combat = _start_combat([3, 2])

	combat.use_skill(skill)

	assert_eq(_dice.remaining_rolls(), 0, "The goblin attacks after an action skill")
	assert_eq(combat.round_number, 2)


func test_second_wind_heals_d10_plus_level() -> void:
	_player.level = 3
	var combat: Combat = _start_combat([7])
	_player.take_damage(12)

	combat.use_skill(SECOND_WIND)

	assert_eq(_player.hit_points, 12, "2 HP + 7 + level 3")
	var params: Array = get_signal_parameters(combat, "combatant_healed", 0)
	var heal: HealRoll = params[1]
	assert_eq(heal.dice_results, [7] as Array[int])
	assert_eq(heal.die_sides, 10, "Second Wind rolls a d10")
	assert_eq(heal.heal_bonus, 3, "The bonus is the current level")
	assert_eq(heal.total, 10)
	assert_eq(params[2], 10)
	assert_eq(params[3], SECOND_WIND, "The heal names the skill that healed")


func test_heal_without_level_bonus_adds_nothing() -> void:
	var skill: SkillData = _healing_skill(SkillData.ActionCost.FREE, NO_USE_LIMIT)
	_player.skills.append(skill)
	_player.level = 3
	var combat: Combat = _start_combat([3])
	_player.take_damage(5)

	combat.use_skill(skill)

	var params: Array = get_signal_parameters(combat, "combatant_healed", 0)
	var heal: HealRoll = params[1]
	assert_eq(heal.heal_bonus, 0, "adds_level = false must ignore the level")
	assert_eq(heal.total, 3)
	assert_eq(_player.hit_points, 12, "9 HP + 3")
	assert_eq(params[3], skill, "The heal names the skill that healed")


func test_healing_stops_at_max_hit_points() -> void:
	var combat: Combat = _start_combat([10])
	_player.take_damage(3)

	combat.use_skill(SECOND_WIND)

	assert_eq(_player.hit_points, _player.max_hit_points)
	var params: Array = get_signal_parameters(combat, "combatant_healed", 0)
	assert_eq((params[1] as HealRoll).total, 11, "10 + level 1 rolled")
	assert_eq(params[2], 3, "Only the 3 missing hit points are restored")


func test_second_wind_reports_skill_used() -> void:
	var combat: Combat = _start_combat([7])

	combat.use_skill(SECOND_WIND)

	assert_signal_emitted_with_parameters(combat, "skill_used", [_player, SECOND_WIND])


func test_skill_used_is_reported_before_the_heal() -> void:
	var combat: Combat = _start_combat([7])
	var order: Array[StringName] = _record_skill_signal_order(combat)

	combat.use_skill(SECOND_WIND)

	assert_eq(order, [&"skill_used", &"combatant_healed"] as Array[StringName])


func test_second_wind_works_once_per_fight() -> void:
	var combat: Combat = _start_combat([7])
	assert_eq(combat.uses_left(SECOND_WIND), 1)

	combat.use_skill(SECOND_WIND)

	assert_eq(combat.uses_left(SECOND_WIND), 0)
	assert_false(combat.can_use_skill(SECOND_WIND))


func test_uses_left_counts_down_with_each_use() -> void:
	var skill: SkillData = _healing_skill(SkillData.ActionCost.FREE, 2)
	_player.skills.append(skill)
	var combat: Combat = _start_combat([3])

	combat.use_skill(skill)

	assert_eq(combat.uses_left(skill), 1)
	assert_true(combat.can_use_skill(skill))


func test_using_a_spent_skill_does_nothing() -> void:
	var combat: Combat = _start_combat([7])
	combat.use_skill(SECOND_WIND)
	_player.take_damage(5)

	combat.use_skill(SECOND_WIND)

	assert_push_error_count(1, "A spent skill must report an error")
	assert_eq(_player.hit_points, 9, "A spent skill must not heal")
	assert_eq(combat.uses_left(SECOND_WIND), 0)
	assert_signal_emit_count(combat, "skill_used", 1, "Only the first use is reported")
	assert_signal_emit_count(combat, "combatant_healed", 1, "Only the first use heals")


func test_skill_uses_reset_in_a_new_fight() -> void:
	var first: Combat = _start_combat([7])
	first.use_skill(SECOND_WIND)

	var second: Combat = _start_combat([])

	assert_true(second.can_use_skill(SECOND_WIND))


func test_unlimited_skill_reports_unlimited_uses() -> void:
	var skill: SkillData = _healing_skill(SkillData.ActionCost.ACTION, NO_USE_LIMIT)
	_player.skills.append(skill)
	var combat: Combat = _start_combat([])

	assert_eq(combat.uses_left(skill), Combat.UNLIMITED_USES)
	assert_true(combat.can_use_skill(skill))


func test_unlimited_skill_stays_unlimited_after_use() -> void:
	var skill: SkillData = _healing_skill(SkillData.ActionCost.FREE, NO_USE_LIMIT)
	_player.skills.append(skill)
	var combat: Combat = _start_combat([3])

	combat.use_skill(skill)

	assert_eq(combat.uses_left(skill), Combat.UNLIMITED_USES)
	assert_true(combat.can_use_skill(skill))


func test_skills_the_player_does_not_own_cannot_be_used() -> void:
	var combat: Combat = _start_combat([])

	assert_false(combat.can_use_skill(_healing_skill(SkillData.ActionCost.ACTION, NO_USE_LIMIT)))


func test_owned_passive_skill_cannot_be_used() -> void:
	var combat: Combat = _start_combat([])

	assert_has(_player.skills, WEAPON_MASTER, "Precondition: the warrior owns Weapon Master")
	assert_false(combat.can_use_skill(WEAPON_MASTER))


func test_skills_cannot_be_used_after_the_fight() -> void:
	var combat: Combat = _start_combat([15, 4])
	combat.player_attack(_goblin)

	assert_true(combat.is_over, "Precondition: the goblin is defeated")
	assert_false(combat.can_use_skill(SECOND_WIND))


func test_active_effect_without_a_rule_reports_an_error() -> void:
	var modifier: StatModifierEffect = StatModifierEffect.new()
	modifier.stat = StatModifierEffect.Stat.ATTACK
	modifier.amount = 1
	var skill: SkillData = SkillData.new()
	skill.id = &"test_active_modifier"
	skill.activation = SkillData.Activation.ACTIVE
	skill.action_cost = SkillData.ActionCost.FREE
	skill.effects = [modifier]
	_player.skills.append(skill)
	var combat: Combat = _start_combat([])

	combat.use_skill(skill)

	assert_push_error_count(1, "Stat modifiers have no rule for active skills")
	assert_signal_not_emitted(combat, "combatant_healed")
