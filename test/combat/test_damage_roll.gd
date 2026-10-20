extends GutTest


func test_total_adds_bonus_to_dice_sum() -> void:
	var damage: DamageRoll = DamageRoll.new([3, 5], 4)

	assert_eq(damage.total, 12)


func test_total_is_at_least_one_when_bonus_is_negative() -> void:
	var damage: DamageRoll = DamageRoll.new([1], -3)

	assert_eq(damage.total, DamageRoll.MINIMUM_DAMAGE)


func test_keeps_single_dice_results_for_display() -> void:
	var damage: DamageRoll = DamageRoll.new([6, 2], 1)

	assert_eq(damage.dice_results, [6, 2] as Array[int])
	assert_eq(damage.damage_bonus, 1)


func test_damage_reduction_comes_off_the_total() -> void:
	var damage: DamageRoll = DamageRoll.new([4], 1, 1)

	assert_eq(damage.total, 4)
	assert_eq(damage.damage_reduction, 1)


func test_rolled_total_is_before_damage_reduction() -> void:
	var damage: DamageRoll = DamageRoll.new([4, 3], 2, 3)

	assert_eq(damage.rolled_total, 9)
	assert_eq(damage.total, 6)


func test_damage_reduction_never_drops_a_hit_below_minimum() -> void:
	var damage: DamageRoll = DamageRoll.new([2], 0, 5)

	assert_eq(damage.total, DamageRoll.MINIMUM_DAMAGE)


func test_without_damage_reduction_total_equals_rolled_total() -> void:
	var damage: DamageRoll = DamageRoll.new([5], 2)

	assert_eq(damage.damage_reduction, 0)
	assert_eq(damage.total, damage.rolled_total)
