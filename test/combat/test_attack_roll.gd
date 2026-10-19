extends GutTest

const NORMAL_CRIT_THRESHOLD: int = 20
const EXTENDED_CRIT_THRESHOLD: int = 19
const UNREACHABLE_ARMOR_CLASS: int = 99
## Natural rolls with +5 against AC 14 and whether they hit narrowly.
const NARROW_HIT_CASES: Array = [[9, true], [10, true], [11, false], [8, false]]


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


func test_narrow_hit_reaches_armor_class_by_at_most_one(
	params: Array = use_parameters(NARROW_HIT_CASES)
) -> void:
	var roll: AttackRoll = AttackRoll.new(params[0], 5, 14, NORMAL_CRIT_THRESHOLD)

	assert_eq(roll.is_narrow_hit, params[1], "%d + 5 vs AC 14" % params[0])


func test_crit_is_never_narrow_hit() -> void:
	var roll: AttackRoll = AttackRoll.new(19, 0, 19, EXTENDED_CRIT_THRESHOLD)

	assert_true(roll.is_crit)
	assert_false(roll.is_narrow_hit, "A crit counts as crit, even when it reaches the AC exactly")
