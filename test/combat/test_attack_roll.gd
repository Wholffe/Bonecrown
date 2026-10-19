extends GutTest

const NORMAL_CRIT_THRESHOLD: int = 20
const EXTENDED_CRIT_THRESHOLD: int = 19
const UNREACHABLE_ARMOR_CLASS: int = 99


func test_total_adds_bonus_to_natural_roll() -> void:
	var roll: AttackRoll = AttackRoll.new(12, 5, 14, NORMAL_CRIT_THRESHOLD)

	assert_eq(roll.total, 17)


func test_total_equal_to_armor_class_hits() -> void:
	var roll: AttackRoll = AttackRoll.new(9, 5, 14, NORMAL_CRIT_THRESHOLD)

	assert_true(roll.is_hit, "9 + 5 = 14 must hit AC 14")


func test_total_one_below_armor_class_misses() -> void:
	var roll: AttackRoll = AttackRoll.new(8, 5, 14, NORMAL_CRIT_THRESHOLD)

	assert_false(roll.is_hit, "8 + 5 = 13 must miss AC 14")


func test_natural_one_misses_even_with_huge_bonus() -> void:
	var roll: AttackRoll = AttackRoll.new(1, 50, 14, NORMAL_CRIT_THRESHOLD)

	assert_false(roll.is_hit)
	assert_true(roll.is_natural_one)
	assert_false(roll.is_crit)


func test_natural_twenty_hits_and_crits_against_unreachable_armor_class() -> void:
	var roll: AttackRoll = AttackRoll.new(20, 0, UNREACHABLE_ARMOR_CLASS, NORMAL_CRIT_THRESHOLD)

	assert_true(roll.is_hit)
	assert_true(roll.is_crit)
	assert_true(roll.is_natural_twenty)


func test_nineteen_in_extended_crit_range_always_hits() -> void:
	var roll: AttackRoll = AttackRoll.new(19, 0, UNREACHABLE_ARMOR_CLASS, EXTENDED_CRIT_THRESHOLD)

	assert_true(roll.is_hit, "Every crit hits, including a 19 in the extended range")
	assert_true(roll.is_crit)
	assert_false(roll.is_natural_twenty, "Only a natural 20 counts as natural twenty")


func test_nineteen_outside_crit_range_is_normal_roll() -> void:
	var roll: AttackRoll = AttackRoll.new(19, 0, UNREACHABLE_ARMOR_CLASS, NORMAL_CRIT_THRESHOLD)

	assert_false(roll.is_hit)
	assert_false(roll.is_crit)


func test_ordinary_hit_is_no_crit_and_no_natural_extreme() -> void:
	var roll: AttackRoll = AttackRoll.new(15, 5, 14, NORMAL_CRIT_THRESHOLD)

	assert_true(roll.is_hit)
	assert_false(roll.is_crit)
	assert_false(roll.is_natural_one)
	assert_false(roll.is_natural_twenty)
