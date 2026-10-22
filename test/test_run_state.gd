extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
const ROLL_COUNT: int = 20
const ELITE_LOOT_BONUS: int = 3


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


func test_room_rewards_are_for_the_room_just_won() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.room_number, RunState.FIRST_ROOM)
	assert_eq(rewards.player, RunState.player)


func test_elite_room_rewards_add_the_elite_loot_bonus() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = RunState.ROOM_TABLE.elite_room

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.loot_roll_bonus(), RunState.player.loot_bonus() + ELITE_LOOT_BONUS)


func test_other_room_rewards_add_no_room_loot_bonus() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.loot_roll_bonus(), RunState.player.loot_bonus())


func test_first_room_has_one_goblin() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	var enemies: Array[Combatant] = RunState.create_room_enemies()

	assert_eq(enemies.size(), 1)
	assert_eq(enemies[0].display_name, "Goblin")


# Scene tests replace the dice after start_new_run, so the room enemies must use the new ones.
func test_room_enemies_roll_with_the_current_run_dice() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var dice: FixedDice = FixedDice.new([2])
	RunState.dice = dice
	RunState.room_number = 4

	var enemies: Array[Combatant] = RunState.create_room_enemies()

	assert_eq(enemies[0].display_name, "Orc", "Roll 2 picks the second encounter of rooms 4-6")
	assert_eq(dice.remaining_rolls(), 0)


func test_advance_room_moves_to_the_next_room() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	RunState.advance_room()

	assert_eq(RunState.room_number, 2)


func test_last_fight_room_is_the_room_before_the_boss() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = RunState.GAME_RULES.room_count - 2
	assert_false(RunState.is_last_fight_room())

	RunState.advance_room()

	assert_true(RunState.is_last_fight_room())
