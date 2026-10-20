extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const SECOND_WIND: SkillData = preload("res://scripts/data/skills/second_wind.tres")
const WEAPON_MASTER: SkillData = preload("res://scripts/data/skills/weapon_master.tres")

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)


func _modifier_skill(
	stat: StatModifierEffect.Stat, amount: int, activation: SkillData.Activation
) -> SkillData:
	var modifier: StatModifierEffect = StatModifierEffect.new()
	modifier.stat = stat
	modifier.amount = amount
	var skill: SkillData = SkillData.new()
	skill.id = &"test_modifier"
	skill.activation = activation
	skill.effects = [modifier]
	return skill


func test_warrior_starts_with_14_hit_points() -> void:
	assert_eq(_warrior.max_hit_points, 14, "12 base + constitution bonus 2")
	assert_eq(_warrior.hit_points, _warrior.max_hit_points)


func test_warrior_starts_at_level_1() -> void:
	assert_eq(_warrior.level, 1)


func test_warrior_armor_class_is_14() -> void:
	assert_eq(_warrior.get_armor_class(), 14, "chain mail 13 + dexterity bonus 1")


func test_warrior_attack_bonus_is_5() -> void:
	assert_eq(_warrior.get_attack_bonus(), 5, "strength bonus 3 + proficiency 2")


func test_warrior_deals_longsword_d8_plus_4() -> void:
	assert_eq(_warrior.get_damage_die_count(), 1)
	assert_eq(_warrior.get_damage_die_sides(), 8)
	assert_eq(_warrior.get_damage_bonus(), 4, "strength bonus 3 + Weapon Master 1")


func test_warrior_crits_only_on_natural_20() -> void:
	assert_eq(_warrior.get_crit_threshold(), 20)


func test_luck_bonus_of_2_extends_crit_range_to_19() -> void:
	var lucky_class: ClassData = WARRIOR.duplicate()
	lucky_class.luck = 14

	var lucky: Character = Character.new(lucky_class, GAME_RULES)

	assert_eq(lucky.get_crit_threshold(), 19)


func test_warrior_starts_with_second_wind_and_weapon_master() -> void:
	assert_eq(_warrior.skills, [SECOND_WIND, WEAPON_MASTER] as Array[SkillData])


func test_active_skills_contain_only_second_wind() -> void:
	assert_eq(_warrior.active_skills(), [SECOND_WIND] as Array[SkillData])


func test_learning_a_skill_leaves_class_data_untouched() -> void:
	var skill: SkillData = _modifier_skill(
		StatModifierEffect.Stat.ATTACK, 1, SkillData.Activation.PASSIVE
	)

	_warrior.skills.append(skill)

	assert_eq(WARRIOR.starting_skills.size(), 2)


func test_learn_skill_leaves_class_data_untouched() -> void:
	_warrior.learn_skill(
		_modifier_skill(StatModifierEffect.Stat.ATTACK, 1, SkillData.Activation.PASSIVE)
	)

	assert_eq(WARRIOR.starting_skills, [SECOND_WIND, WEAPON_MASTER] as Array[SkillData])


func test_learning_a_skill_twice_keeps_both_copies() -> void:
	var skill: SkillData = _modifier_skill(
		StatModifierEffect.Stat.ATTACK, 1, SkillData.Activation.PASSIVE
	)

	_warrior.learn_skill(skill)
	_warrior.learn_skill(skill)

	assert_eq(_warrior.skills.count(skill), 2)
	assert_eq(_warrior.get_attack_bonus(), 7, "5 + 1 per copy")


func test_passive_attack_modifier_raises_attack_bonus() -> void:
	_warrior.skills.append(
		_modifier_skill(StatModifierEffect.Stat.ATTACK, 1, SkillData.Activation.PASSIVE)
	)

	assert_eq(_warrior.get_attack_bonus(), 6)


func test_passive_armor_class_modifier_raises_armor_class() -> void:
	_warrior.skills.append(
		_modifier_skill(StatModifierEffect.Stat.ARMOR_CLASS, 1, SkillData.Activation.PASSIVE)
	)

	assert_eq(_warrior.get_armor_class(), 15)


func test_stat_modifiers_on_active_skills_are_ignored() -> void:
	_warrior.skills.append(
		_modifier_skill(StatModifierEffect.Stat.ATTACK, 3, SkillData.Activation.ACTIVE)
	)

	assert_eq(_warrior.get_attack_bonus(), 5)
