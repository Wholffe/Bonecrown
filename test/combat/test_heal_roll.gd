extends GutTest


func test_total_adds_bonus_to_dice_sum() -> void:
	var heal: HealRoll = HealRoll.new([3, 5], 2)

	assert_eq(heal.total, 10)


func test_total_without_bonus_is_dice_sum() -> void:
	var heal: HealRoll = HealRoll.new([7], 0)

	assert_eq(heal.total, 7)


func test_keeps_single_dice_results_for_display() -> void:
	var heal: HealRoll = HealRoll.new([6, 2], 3)

	assert_eq(heal.dice_results, [6, 2] as Array[int])
	assert_eq(heal.heal_bonus, 3)
