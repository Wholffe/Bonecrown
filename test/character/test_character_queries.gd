extends GutTest
## Character queries for the post-fight screen: copies, capped attributes, loot bonus and slots.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const STRENGTH_TRAINING: SkillData = preload("res://scripts/data/skills/strength_training.tres")
const HONED_LONGSWORD: WeaponData = preload("res://scripts/data/items/honed_longsword.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
const VIGOR_AMULET: TalismanData = preload("res://scripts/data/items/vigor_amulet.tres")

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)


func test_copy_has_the_same_values() -> void:
	_warrior.level_up()
	_warrior.learn_skill(STRENGTH_TRAINING)
	_warrior.equip(LUCKY_COIN)
	_warrior.take_damage(5)

	var copy: Character = _warrior.copy()

	assert_eq(copy.level, 2)
	assert_eq(copy.skills, _warrior.skills)
	assert_eq(copy.talisman, LUCKY_COIN)
	assert_eq(copy.max_hit_points, 22)
	assert_eq(copy.hit_points, 17)
	assert_eq(copy.get_attack_bonus(), _warrior.get_attack_bonus())


func test_changing_a_copy_leaves_the_original_alone() -> void:
	var copy: Character = _warrior.copy()

	copy.learn_skill(STRENGTH_TRAINING)
	copy.equip(HONED_LONGSWORD)
	copy.take_damage(4)

	assert_eq(_warrior.skills.size(), 2)
	assert_eq(_warrior.weapon, WARRIOR.starting_weapon)
	assert_eq(_warrior.hit_points, 14)


func test_no_attribute_is_capped_at_the_start() -> void:
	assert_eq(_warrior.capped_attribute_stats().size(), 0)


func test_capped_strength_is_reported_as_its_modifier_stat() -> void:
	_warrior.learn_skill(STRENGTH_TRAINING)
	_warrior.learn_skill(STRENGTH_TRAINING)

	assert_eq(
		_warrior.capped_attribute_stats(),
		[StatModifierEffect.Stat.STRENGTH] as Array[StatModifierEffect.Stat]
	)


func test_loot_bonus_is_the_luck_bonus() -> void:
	assert_eq(_warrior.loot_bonus(), 0)

	_warrior.equip(LUCKY_COIN)

	assert_eq(_warrior.loot_bonus(), 1)


func test_hit_points_per_level_up_follow_constitution() -> void:
	assert_eq(_warrior.hit_points_per_level_up(), 8)

	_warrior.equip(VIGOR_AMULET)

	assert_eq(_warrior.hit_points_per_level_up(), 9)


func test_item_in_slot_returns_the_worn_items() -> void:
	assert_eq(_warrior.item_in_slot(ItemData.Slot.WEAPON), WARRIOR.starting_weapon)
	assert_eq(_warrior.item_in_slot(ItemData.Slot.ARMOR), WARRIOR.starting_armor)
	assert_null(_warrior.item_in_slot(ItemData.Slot.TALISMAN))


func test_worn_items_leave_out_the_empty_slot() -> void:
	assert_eq(
		_warrior.worn_items(), [WARRIOR.starting_weapon, WARRIOR.starting_armor] as Array[ItemData]
	)
