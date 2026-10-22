extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const BONE_KING: EnemyData = preload("res://scripts/data/enemies/bone_king.tres")
const TREASURE: DoorRewardData = preload("res://scripts/data/doors/treasure.tres")
const HEALING_SPRING: DoorRewardData = preload("res://scripts/data/doors/healing_spring.tres")
const SEED: int = 42
const ROLL_COUNT: int = 20
const ELITE_LOOT_BONUS: int = 3


func _roll_sequence() -> Array[int]:
	var rolls: Array[int] = []
	for _i: int in ROLL_COUNT:
		rolls.append(RunState.dice.roll(AttackRoll.DIE_SIDES))
	return rolls


func _door_with_reward(reward: DoorRewardData) -> DoorOption:
	var door: DoorOption = GoblinPairDoor.create()
	door.reward = reward
	return door


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


func test_boss_room_is_the_last_room() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = RunState.GAME_RULES.room_count - 1
	assert_false(RunState.is_boss_room())

	RunState.advance_room()

	assert_true(RunState.is_boss_room())


func test_boss_room_has_the_boss() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = RunState.GAME_RULES.room_count

	var enemies: Array[Combatant] = RunState.create_room_enemies()

	assert_eq(enemies.size(), 1)
	assert_eq((enemies[0] as Enemy).data, BONE_KING)


func test_door_rooms_lie_between_the_first_room_and_the_boss_room() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	for room: int in range(RunState.FIRST_ROOM, RunState.GAME_RULES.room_count + 1):
		RunState.room_number = room
		var expected: bool = room > RunState.FIRST_ROOM and not RunState.is_boss_room()
		assert_eq(RunState.is_door_room(), expected, "room %d" % room)


func test_doors_roll_with_the_current_run_dice() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = 2
	# d2 = 2 puts the single goblin behind the left door, d100 = 100 misses the reward chance.
	var dice: FixedDice = FixedDice.new([2, 100])
	RunState.dice = dice

	var doors: Array[DoorOption] = RunState.roll_doors()

	assert_eq(doors.size(), 2)
	assert_eq(doors[0].enemies.size(), 1)
	assert_eq(doors[1].enemies.size(), 2)
	assert_eq(dice.remaining_rolls(), 0)


func test_chosen_door_gives_the_room_enemies_without_a_roll() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.advance_room()
	var door: DoorOption = GoblinPairDoor.create()
	RunState.dice = FixedDice.new([])

	RunState.choose_door(door)

	assert_eq(RunState.chosen_door, door)
	assert_eq(RunState.create_room_enemies(), door.enemies)


func test_chosen_door_is_cleared_in_the_next_room_and_a_new_run() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.choose_door(GoblinPairDoor.create())

	RunState.advance_room()

	assert_null(RunState.chosen_door, "Next room")
	RunState.choose_door(GoblinPairDoor.create())
	RunState.start_new_run(WARRIOR, SEED)
	assert_null(RunState.chosen_door, "New run")


func test_treasure_door_adds_its_loot_bonus_to_the_room_rewards() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = RunState.ROOM_TABLE.elite_room
	RunState.choose_door(_door_with_reward(TREASURE))

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(
		rewards.loot_roll_bonus(),
		RunState.player.loot_bonus() + ELITE_LOOT_BONUS + TREASURE.loot_bonus
	)


func test_healing_spring_door_heals_after_the_fight() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.player.take_damage(10)
	RunState.choose_door(_door_with_reward(HEALING_SPRING))

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.door_reward, HEALING_SPRING)
	assert_eq(rewards.heal_from_door_reward(), 1, "10% of 14 HP, rounded down")
	assert_eq(RunState.player.hit_points, 5)
