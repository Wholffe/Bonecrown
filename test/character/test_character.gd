extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES.proficiency_bonus)


func test_warrior_starts_with_14_hit_points() -> void:
	assert_eq(_warrior.max_hit_points, 14, "12 base + constitution bonus 2")
	assert_eq(_warrior.hit_points, _warrior.max_hit_points)


func test_warrior_starts_at_level_1() -> void:
	assert_eq(_warrior.level, 1)


func test_warrior_armor_class_is_14() -> void:
	assert_eq(_warrior.get_armor_class(), 14, "chain mail 13 + dexterity bonus 1")


func test_warrior_attack_bonus_is_5() -> void:
	assert_eq(_warrior.get_attack_bonus(), 5, "strength bonus 3 + proficiency 2")


func test_warrior_deals_longsword_d8_plus_strength_bonus() -> void:
	assert_eq(_warrior.get_damage_die_count(), 1)
	assert_eq(_warrior.get_damage_die_sides(), 8)
	assert_eq(_warrior.get_damage_bonus(), 3)


func test_warrior_crits_only_on_natural_20() -> void:
	assert_eq(_warrior.get_crit_threshold(), 20)


func test_luck_bonus_of_2_extends_crit_range_to_19() -> void:
	var lucky_class: ClassData = WARRIOR.duplicate()
	lucky_class.luck = 14

	var lucky: Character = Character.new(lucky_class, GAME_RULES.proficiency_bonus)

	assert_eq(lucky.get_crit_threshold(), 19)
