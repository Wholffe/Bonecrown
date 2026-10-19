extends GutTest


func test_total_adds_bonus_to_dice_sum() -> void:
	var heal: HealRoll = HealRoll.new([3, 5], 6, 2)

	assert_eq(heal.total, 10)


func test_total_without_bonus_is_dice_sum() -> void:
	var heal: HealRoll = HealRoll.new([7], 10, 0)

	assert_eq(heal.total, 7)


func test_keeps_single_dice_results_for_display() -> void:
	var heal: HealRoll = HealRoll.new([6, 2], 8, 3)

	assert_eq(heal.dice_results, [6, 2] as Array[int])
	assert_eq(heal.heal_bonus, 3)


func test_keeps_die_sides_for_display() -> void:
	var heal: HealRoll = HealRoll.new([4, 1], 4, 0)

	assert_eq(heal.die_sides, 4)
