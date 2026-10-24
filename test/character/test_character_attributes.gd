extends GutTest
## Effective attributes of Character: skill and item modifiers, stacking, the attribute cap and the
## bonuses derived from the effective values.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const STRENGTH_TRAINING: SkillData = preload("res://scripts/data/skills/strength_training.tres")
const FOOTWORK: SkillData = preload("res://scripts/data/skills/footwork.tres")
const TOUGHNESS: SkillData = preload("res://scripts/data/skills/toughness.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
const FOUR_LEAF_CLOVER: TalismanData = preload("res://scripts/data/items/four_leaf_clover.tres")
const VIGOR_AMULET: TalismanData = preload("res://scripts/data/items/vigor_amulet.tres")
const RUNED_LONGSWORD: WeaponData = preload("res://scripts/data/items/runed_longsword.tres")

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)


func _learn_times(skill: SkillData, times: int) -> void:
	for _index: int in times:
		_warrior.learn_skill(skill)


func test_attributes_without_modifiers_are_the_class_values() -> void:
	assert_eq(_warrior.attribute_value(Attributes.Kind.STRENGTH), WARRIOR.strength)
	assert_eq(_warrior.attribute_value(Attributes.Kind.DEXTERITY), WARRIOR.dexterity)
	assert_eq(_warrior.attribute_value(Attributes.Kind.CONSTITUTION), WARRIOR.constitution)
	assert_eq(_warrior.attribute_value(Attributes.Kind.LUCK), WARRIOR.luck)


func test_strength_training_raises_effective_strength_by_2() -> void:
	_warrior.learn_skill(STRENGTH_TRAINING)

	assert_eq(_warrior.attribute_value(Attributes.Kind.STRENGTH), 18, "16 + 2")


func test_skill_learned_twice_counts_twice() -> void:
	_learn_times(FOOTWORK, 2)

	assert_eq(_warrior.attribute_value(Attributes.Kind.DEXTERITY), 16, "12 + 2 × 2")


func test_worn_item_raises_effective_attribute() -> void:
	_warrior.equip(LUCKY_COIN)

	assert_eq(_warrior.attribute_value(Attributes.Kind.LUCK), 12, "10 + Lucky Coin 2")


func test_skill_and_item_modifiers_on_one_attribute_add_up() -> void:
	_warrior.learn_skill(TOUGHNESS)
	_warrior.equip(VIGOR_AMULET)

	assert_eq(_warrior.attribute_value(Attributes.Kind.CONSTITUTION), 18, "14 + 2 + 2")


func test_modifiers_leave_the_base_attributes_unchanged() -> void:
	_warrior.learn_skill(STRENGTH_TRAINING)

	assert_eq(_warrior.attributes.value_of(Attributes.Kind.STRENGTH), WARRIOR.strength)


func test_attribute_value_stops_at_the_cap() -> void:
	_learn_times(STRENGTH_TRAINING, 3)

	assert_eq(
		_warrior.attribute_value(Attributes.Kind.STRENGTH),
		GAME_RULES.attribute_cap,
		"16 + 3 × 2 = 22 is capped"
	)


func test_attribute_is_capped_once_it_reaches_the_cap() -> void:
	_learn_times(STRENGTH_TRAINING, 2)

	assert_eq(_warrior.attribute_value(Attributes.Kind.STRENGTH), GAME_RULES.attribute_cap)
	assert_true(_warrior.is_attribute_capped(Attributes.Kind.STRENGTH))


func test_attribute_is_not_capped_below_the_cap() -> void:
	_warrior.learn_skill(STRENGTH_TRAINING)

	assert_false(_warrior.is_attribute_capped(Attributes.Kind.STRENGTH), "18 is below the cap")
	assert_false(_warrior.is_attribute_capped(Attributes.Kind.DEXTERITY), "12 is untouched")


func test_attribute_cap_comes_from_the_game_rules() -> void:
	var strict_rules: GameRulesData = GAME_RULES.duplicate()
	strict_rules.attribute_cap = 17
	var warrior: Character = Character.new(WARRIOR, strict_rules)

	warrior.learn_skill(STRENGTH_TRAINING)

	assert_eq(warrior.attribute_value(Attributes.Kind.STRENGTH), 17)
	assert_true(warrior.is_attribute_capped(Attributes.Kind.STRENGTH))


func test_attack_bonus_follows_effective_strength() -> void:
	_warrior.learn_skill(STRENGTH_TRAINING)

	assert_eq(_warrior.get_attack_bonus(), 6, "strength 18 bonus 4 + proficiency 2")


func test_damage_bonus_follows_effective_strength() -> void:
	_warrior.learn_skill(STRENGTH_TRAINING)

	assert_eq(_warrior.get_damage_bonus(), 5, "strength 18 bonus 4 + Weapon Master 1")


func test_capped_strength_limits_attack_and_damage_bonus() -> void:
	_learn_times(STRENGTH_TRAINING, 3)

	assert_eq(_warrior.get_attack_bonus(), 7, "capped strength 20 bonus 5 + proficiency 2")
	assert_eq(_warrior.get_damage_bonus(), 6, "capped strength 20 bonus 5 + Weapon Master 1")


func test_armor_class_follows_effective_dexterity() -> void:
	_warrior.learn_skill(FOOTWORK)

	assert_eq(_warrior.get_armor_class(), 15, "chain mail 13 + dexterity 14 bonus 2")


func test_crit_threshold_is_19_at_effective_luck_14() -> void:
	_warrior.equip(LUCKY_COIN)
	_warrior.equip(RUNED_LONGSWORD)

	assert_eq(_warrior.attribute_value(Attributes.Kind.LUCK), 14, "10 + 2 + 2")
	assert_eq(_warrior.get_crit_threshold(), CombatFormulas.EXTENDED_CRIT_THRESHOLD)


func test_crit_threshold_stays_20_below_effective_luck_14() -> void:
	_warrior.equip(LUCKY_COIN)

	assert_eq(_warrior.get_crit_threshold(), AttackRoll.DIE_SIDES, "luck 12 has bonus 1")


func test_four_leaf_clover_extends_crit_range_to_19() -> void:
	_warrior.equip(FOUR_LEAF_CLOVER)

	assert_eq(_warrior.get_crit_threshold(), CombatFormulas.EXTENDED_CRIT_THRESHOLD)
