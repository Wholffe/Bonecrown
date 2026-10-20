extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
const ROLL_COUNT: int = 20
const GOBLIN_ID: StringName = &"goblin"


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


func test_new_run_forgets_enemy_knowledge_of_the_last_run() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.enemy_knowledge.record_player_attack(
		GOBLIN_ID, AttackRoll.new(12, 5, 14, AttackRoll.DIE_SIDES)
	)
	RunState.enemy_knowledge.record_enemy_attack(
		GOBLIN_ID, AttackRoll.new(10, 3, 14, AttackRoll.DIE_SIDES)
	)

	RunState.start_new_run(WARRIOR, SEED)

	assert_eq(RunState.enemy_knowledge.highest_armor_class(GOBLIN_ID), EnemyKnowledge.UNKNOWN)
	assert_false(RunState.enemy_knowledge.is_attack_bonus_known(GOBLIN_ID))


func test_room_rewards_are_for_the_room_just_won() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.room_number, RunState.FIRST_ROOM)
	assert_eq(rewards.player, RunState.player)


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
