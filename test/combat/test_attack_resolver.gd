extends GutTest

const NORMAL_CRIT_THRESHOLD: int = 20
const LONGSWORD_SIDES: int = 8


func test_roll_attack_uses_next_d20_roll() -> void:
	var resolver: AttackResolver = AttackResolver.new(FixedDice.new([13]))

	var roll: AttackRoll = resolver.roll_attack(5, 14, NORMAL_CRIT_THRESHOLD)

	assert_eq(roll.natural_roll, 13)
	assert_eq(roll.attack_bonus, 5)
	assert_eq(roll.target_armor_class, 14)
	assert_true(roll.is_hit)


func test_roll_damage_rolls_dice_once_and_adds_bonus() -> void:
	var dice: FixedDice = FixedDice.new([6])
	var resolver: AttackResolver = AttackResolver.new(dice)

	var damage: DamageRoll = resolver.roll_damage(1, LONGSWORD_SIDES, 3, false)

	assert_eq(damage.dice_results, [6] as Array[int])
	assert_eq(damage.total, 9)
	assert_eq(dice.remaining_rolls(), 0)


func test_doubled_damage_rolls_twice_as_many_dice_but_bonus_once() -> void:
	var dice: FixedDice = FixedDice.new([6, 4])
	var resolver: AttackResolver = AttackResolver.new(dice)

	var damage: DamageRoll = resolver.roll_damage(1, LONGSWORD_SIDES, 3, true)

	assert_eq(damage.dice_results, [6, 4] as Array[int])
	assert_eq(damage.total, 13, "6 + 4 + 3: dice doubled, bonus not")
	assert_eq(dice.remaining_rolls(), 0)


func test_normal_roll_uses_one_d20() -> void:
	var dice: FixedDice = FixedDice.new([13])
	var resolver: AttackResolver = AttackResolver.new(dice)

	var roll: AttackRoll = resolver.roll_attack(5, 14, NORMAL_CRIT_THRESHOLD)

	assert_eq(roll.roll_mode, AttackRoll.RollMode.NORMAL)
	assert_eq(roll.discarded_roll, 0)
	assert_eq(dice.remaining_rolls(), 0)


func test_advantage_keeps_the_higher_d20() -> void:
	var resolver: AttackResolver = AttackResolver.new(FixedDice.new([4, 15]))

	var roll: AttackRoll = resolver.roll_attack(
		5, 14, NORMAL_CRIT_THRESHOLD, AttackRoll.RollMode.ADVANTAGE
	)

	assert_eq(roll.roll_mode, AttackRoll.RollMode.ADVANTAGE)
	assert_eq(roll.natural_roll, 15)
	assert_eq(roll.discarded_roll, 4)
	assert_eq(roll.total, 20)


func test_disadvantage_keeps_the_lower_d20() -> void:
	var resolver: AttackResolver = AttackResolver.new(FixedDice.new([15, 4]))

	var roll: AttackRoll = resolver.roll_attack(
		5, 14, NORMAL_CRIT_THRESHOLD, AttackRoll.RollMode.DISADVANTAGE
	)

	assert_eq(roll.roll_mode, AttackRoll.RollMode.DISADVANTAGE)
	assert_eq(roll.natural_roll, 4)
	assert_eq(roll.discarded_roll, 15)
	assert_false(roll.is_hit, "4 + 5 = 9 misses AC 14")


func test_natural_twenty_on_the_discarded_d20_is_no_crit() -> void:
	var resolver: AttackResolver = AttackResolver.new(FixedDice.new([20, 9]))

	var roll: AttackRoll = resolver.roll_attack(
		5, 14, NORMAL_CRIT_THRESHOLD, AttackRoll.RollMode.DISADVANTAGE
	)

	assert_false(roll.is_natural_twenty)
	assert_false(roll.is_crit)
	assert_true(roll.is_hit, "9 + 5 = 14 still hits AC 14")


func test_natural_one_on_the_discarded_d20_does_not_count() -> void:
	var resolver: AttackResolver = AttackResolver.new(FixedDice.new([1, 12]))

	var roll: AttackRoll = resolver.roll_attack(
		5, 14, NORMAL_CRIT_THRESHOLD, AttackRoll.RollMode.ADVANTAGE
	)

	assert_false(roll.is_natural_one)
	assert_true(roll.is_hit)


func test_roll_damage_passes_the_damage_reduction_on() -> void:
	var resolver: AttackResolver = AttackResolver.new(FixedDice.new([6]))

	var damage: DamageRoll = resolver.roll_damage(1, LONGSWORD_SIDES, 3, false, 2)

	assert_eq(damage.rolled_total, 9)
	assert_eq(damage.total, 7)
