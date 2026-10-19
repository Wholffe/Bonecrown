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
