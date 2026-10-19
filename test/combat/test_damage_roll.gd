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
