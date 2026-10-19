extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
const ROLL_COUNT: int = 20


func _roll_sequence() -> Array[int]:
	var rolls: Array[int] = []
	for _i: int in ROLL_COUNT:
		rolls.append(RunState.dice.roll(AttackRoll.DIE_SIDES))
	return rolls


func test_new_run_starts_in_first_room_with_full_health() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	assert_eq(RunState.run_seed, SEED)
	assert_eq(RunState.room_number, 1)
	assert_eq(RunState.player.hit_points, RunState.player.max_hit_points)


func test_same_seed_repeats_the_run_dice() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var first: Array[int] = _roll_sequence()
	RunState.start_new_run(WARRIOR, SEED)
	var second: Array[int] = _roll_sequence()

	assert_eq(first, second)
