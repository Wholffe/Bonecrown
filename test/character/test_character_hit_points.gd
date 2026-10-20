extends GutTest
## Hit points of Character: the 5e max HP formula, level-ups without a full heal and max HP that
## follows Constitution changes from skills and items.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const TOUGHNESS: SkillData = preload("res://scripts/data/skills/toughness.tres")
const PRECISION: SkillData = preload("res://scripts/data/skills/precision.tres")
const VIGOR_AMULET: TalismanData = preload("res://scripts/data/items/vigor_amulet.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
const DWARVEN_CHAIN_MAIL: ArmorData = preload("res://scripts/data/items/dwarven_chain_mail.tres")
const HONED_LONGSWORD: WeaponData = preload("res://scripts/data/items/honed_longsword.tres")
## [level, expected max HP] for the Warrior: 12 + 2 + (level - 1) × (6 + 2).
const MAX_HIT_POINTS_CASES: Array = [[1, 14], [2, 22], [3, 30], [10, 86]]
## Hit points the Warrior gains per level-up: 6 per level + constitution bonus 2.
const WARRIOR_LEVEL_UP_GAIN: int = 8

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)


func _level_up_to(target_level: int) -> void:
	while _warrior.level < target_level:
		_warrior.level_up()


func test_max_hit_points_follow_the_level_formula(
	params: Array = use_parameters(MAX_HIT_POINTS_CASES)
) -> void:
	_level_up_to(params[0])

	assert_eq(_warrior.max_hit_points, params[1], "level %d" % params[0])


func test_level_up_raises_level_by_1() -> void:
	_warrior.level_up()

	assert_eq(_warrior.level, Character.STARTING_LEVEL + 1)


func test_level_up_raises_max_hit_points_by_6_plus_constitution_bonus() -> void:
	var before: int = _warrior.max_hit_points

	_warrior.level_up()

	assert_eq(_warrior.max_hit_points - before, WARRIOR_LEVEL_UP_GAIN)


func test_level_up_raises_current_hit_points_by_the_same_amount() -> void:
	_warrior.level_up()

	assert_eq(_warrior.hit_points, 22, "14 + 8")


func test_level_up_keeps_missing_hit_points_missing() -> void:
	_warrior.take_damage(5)

	_warrior.level_up()

	assert_eq(_warrior.hit_points, 17, "9 + 8, no full heal")
	assert_eq(_warrior.max_hit_points - _warrior.hit_points, 5)


func test_toughness_at_level_3_adds_3_max_hit_points() -> void:
	_level_up_to(3)

	_warrior.learn_skill(TOUGHNESS)

	assert_eq(_warrior.max_hit_points, 33, "30 + 1 per level reached")


func test_toughness_at_level_3_adds_3_current_hit_points() -> void:
	_level_up_to(3)
	_warrior.take_damage(10)

	_warrior.learn_skill(TOUGHNESS)

	assert_eq(_warrior.hit_points, 23, "20 + 3")


func test_level_up_after_toughness_gains_9() -> void:
	_level_up_to(3)
	_warrior.learn_skill(TOUGHNESS)

	_warrior.level_up()

	assert_eq(_warrior.max_hit_points, 42, "33 + 6 + constitution 16 bonus 3")


func test_constitution_beyond_the_cap_adds_no_hit_points() -> void:
	for _index: int in 3:
		_warrior.learn_skill(TOUGHNESS)
	var at_cap: int = _warrior.max_hit_points

	_warrior.learn_skill(TOUGHNESS)

	assert_eq(at_cap, 17, "12 + constitution 20 bonus 5")
	assert_eq(_warrior.max_hit_points, at_cap)


func test_constitution_item_raises_max_and_current_hit_points() -> void:
	_level_up_to(3)
	_warrior.take_damage(10)

	_warrior.equip(VIGOR_AMULET)

	assert_eq(_warrior.max_hit_points, 33, "30 + 1 per level reached")
	assert_eq(_warrior.hit_points, 23, "20 + 3")


func test_swapping_out_a_constitution_item_lowers_max_hit_points() -> void:
	_level_up_to(3)
	_warrior.equip(VIGOR_AMULET)

	_warrior.equip(LUCKY_COIN)

	assert_eq(_warrior.max_hit_points, 30)


func test_swapping_out_a_constitution_item_clamps_full_hit_points() -> void:
	_level_up_to(3)
	_warrior.equip(VIGOR_AMULET)

	_warrior.equip(LUCKY_COIN)

	assert_eq(_warrior.hit_points, 30, "33 clamped to the new maximum")


func test_swapping_out_a_constitution_item_clamps_hit_points_one_above_the_new_max() -> void:
	_level_up_to(3)
	_warrior.equip(VIGOR_AMULET)
	_warrior.take_damage(2)

	_warrior.equip(LUCKY_COIN)

	assert_eq(_warrior.hit_points, 30, "31 clamped to the new maximum")


func test_swapping_out_a_constitution_item_keeps_hit_points_below_the_new_max() -> void:
	_level_up_to(3)
	_warrior.equip(VIGOR_AMULET)
	_warrior.take_damage(13)

	_warrior.equip(LUCKY_COIN)

	assert_eq(_warrior.hit_points, 20, "20 is below the new maximum 30")


func test_swapping_out_constitution_armor_lowers_max_hit_points() -> void:
	_level_up_to(3)
	_warrior.equip(DWARVEN_CHAIN_MAIL)

	_warrior.equip(WARRIOR.starting_armor)

	assert_eq(_warrior.max_hit_points, 30)


func test_learning_a_skill_without_constitution_keeps_missing_hit_points() -> void:
	_warrior.take_damage(5)

	_warrior.learn_skill(PRECISION)

	assert_eq(_warrior.max_hit_points, 14)
	assert_eq(_warrior.hit_points, 9)


func test_equipping_an_item_without_constitution_keeps_missing_hit_points() -> void:
	_warrior.take_damage(5)

	_warrior.equip(HONED_LONGSWORD)

	assert_eq(_warrior.max_hit_points, 14)
	assert_eq(_warrior.hit_points, 9)
