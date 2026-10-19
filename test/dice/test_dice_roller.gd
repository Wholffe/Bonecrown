extends GutTest

const SEED: int = 12345
const ROLL_COUNT: int = 600


func _roll_sequence(dice: DiceRoller, sides: int) -> Array[int]:
	var rolls: Array[int] = []
	for _i: int in ROLL_COUNT:
		rolls.append(dice.roll(sides))
	return rolls


func test_same_seed_gives_same_rolls() -> void:
	var first: Array[int] = _roll_sequence(DiceRoller.new(SEED), 20)
	var second: Array[int] = _roll_sequence(DiceRoller.new(SEED), 20)

	assert_eq(first, second)


func test_different_seeds_give_different_rolls() -> void:
	var first: Array[int] = _roll_sequence(DiceRoller.new(SEED), 20)
	var second: Array[int] = _roll_sequence(DiceRoller.new(SEED + 1), 20)

	assert_ne(first, second)


func test_rolls_cover_every_face_and_nothing_else() -> void:
	var rolls: Array[int] = _roll_sequence(DiceRoller.new(SEED), 6)

	for face: int in range(1, 7):
		assert_has(rolls, face)
	for roll: int in rolls:
		assert_between(roll, 1, 6)


func test_one_sided_die_always_rolls_one() -> void:
	var dice: DiceRoller = DiceRoller.new(SEED)

	assert_eq(dice.roll(1), 1)


func test_roll_many_returns_one_result_per_die() -> void:
	var results: Array[int] = DiceRoller.new(SEED).roll_many(3, 6)

	assert_eq(results.size(), 3)
	for result: int in results:
		assert_between(result, 1, 6)


func test_roll_many_with_zero_dice_returns_no_results() -> void:
	var results: Array[int] = DiceRoller.new(SEED).roll_many(0, 6)

	assert_eq(results, [] as Array[int])
