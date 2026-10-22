extends GutTest
## DoorRoller: the encounters behind the doors, the reward chance and the door that gets the reward.

const ROOM_TABLE: RoomTableData = preload("res://scripts/data/rooms/room_table.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const TREASURE: DoorRewardData = preload("res://scripts/data/doors/treasure.tres")
const HEALING_SPRING: DoorRewardData = preload("res://scripts/data/doors/healing_spring.tres")
const FIRST_ROOM: int = 1
const ELITE_ROOM: int = 5
## The test tables put every room into one tier over rooms 1 to 9.
const TEST_ROOM: int = 2
const REWARD_CHANCE: int = 75
## d100 rolls on the reward chance of REWARD_CHANCE.
const REWARD_HIT: int = 1
const REWARD_MISS: int = 100
const MAX_ENEMIES_PER_ENCOUNTER: int = 3
const SEED_COUNT: int = 30
## [d100 roll, whether a door gets the reward] at a chance of 75%.
const REWARD_CHANCE_CASES: Array = [[1, true], [75, true], [76, false], [100, false]]
## [first door's roll, index of the door with the reward] for doors of 8 and 16 hit points.
const HARDEST_DOOR_CASES: Array = [[1, 1], [2, 0]]

var _dice: FixedDice


func _roller(table: RoomTableData, rolls: Array[int]) -> DoorRoller:
	_dice = FixedDice.new(rolls)
	return DoorRoller.new(_dice, table)


## One enemy type per hit point value, so encounters are told apart by their hit points.
func _encounter(hit_points: Array[int]) -> EncounterData:
	var encounter: EncounterData = EncounterData.new()
	for value: int in hit_points:
		var enemy_data: EnemyData = EnemyData.new()
		enemy_data.id = StringName("test_enemy_%d" % value)
		enemy_data.display_name = "Test Enemy %d" % value
		enemy_data.max_hit_points = value
		encounter.enemies.append(enemy_data)
	return encounter


## One unscaled tier over rooms 1 to 9, two doors per room from room 2 on, no elite room.
func _table(encounters: Array[EncounterData], rewards: Array[DoorRewardData]) -> RoomTableData:
	var tier: RoomTierData = RoomTierData.new()
	tier.first_room = 1
	tier.last_room = 9
	tier.encounters = encounters
	var table: RoomTableData = RoomTableData.new()
	table.tiers = [tier]
	table.scaling_room_step = 3
	table.first_door_room = 2
	table.doors_per_room = 2
	table.door_reward_chance_percent = REWARD_CHANCE
	table.door_rewards = rewards
	table.boss_room = 10
	return table


func _treasure_only() -> Array[DoorRewardData]:
	var rewards: Array[DoorRewardData] = [TREASURE]
	return rewards


func _rewards_of(doors: Array[DoorOption]) -> Array[DoorRewardData]:
	var rewards: Array[DoorRewardData] = []
	for door: DoorOption in doors:
		rewards.append(door.reward)
	return rewards


func test_only_rooms_from_the_first_door_room_to_before_the_boss_have_doors() -> void:
	var roller: DoorRoller = _roller(ROOM_TABLE, [])

	for room: int in range(FIRST_ROOM, GAME_RULES.room_count + 1):
		var expected: bool = room >= 2 and room < GAME_RULES.room_count
		assert_eq(roller.has_doors(room), expected, "room %d" % room)


func test_doors_draw_distinct_encounters_by_one_roll_each() -> void:
	var first: EncounterData = _encounter([8])
	var second: EncounterData = _encounter([9])
	var third: EncounterData = _encounter([10])
	var table: RoomTableData = _table([first, second, third], _treasure_only())

	# d3 = 1 picks the first, d2 = 1 the first of the two left.
	var doors: Array[DoorOption] = _roller(table, [1, 1, REWARD_MISS]).roll_doors(TEST_ROOM)

	assert_eq(doors.size(), 2)
	assert_eq(doors[0].encounter, first)
	assert_eq(doors[1].encounter, second)
	assert_eq(_dice.remaining_rolls(), 0)


func test_last_encounter_left_needs_no_roll() -> void:
	var first: EncounterData = _encounter([8])
	var second: EncounterData = _encounter([9])
	var table: RoomTableData = _table([first, second], _treasure_only())

	var doors: Array[DoorOption] = _roller(table, [2, REWARD_MISS]).roll_doors(TEST_ROOM)

	assert_eq(doors[0].encounter, second)
	assert_eq(doors[1].encounter, first)
	assert_eq(_dice.remaining_rolls(), 0)


func test_pool_of_one_encounter_repeats_it_with_own_enemies() -> void:
	var only: EncounterData = _encounter([8, 8])
	var table: RoomTableData = _table([only], _treasure_only())

	var doors: Array[DoorOption] = _roller(table, [REWARD_MISS]).roll_doors(TEST_ROOM)

	assert_eq(doors[0].encounter, only)
	assert_eq(doors[1].encounter, only)
	assert_ne(doors[0].enemies[0], doors[1].enemies[0], "Each door creates its own enemies")
	assert_eq(_dice.remaining_rolls(), 0)


func test_reward_chance_decides_whether_a_door_gets_a_reward(
	params: Array = use_parameters(REWARD_CHANCE_CASES)
) -> void:
	var table: RoomTableData = _table([_encounter([8])], _treasure_only())

	var doors: Array[DoorOption] = _roller(table, [params[0]]).roll_doors(TEST_ROOM)

	var rewards: Array[DoorRewardData] = _rewards_of(doors)
	assert_eq(rewards.has(TREASURE), params[1], "d100 roll %d" % params[0])
	assert_eq(_dice.remaining_rolls(), 0, "A single reward needs no pick roll")


func test_reward_is_picked_from_the_rewards_by_one_roll() -> void:
	var rewards: Array[DoorRewardData] = [TREASURE, HEALING_SPRING]
	var table: RoomTableData = _table([_encounter([8])], rewards)

	var first_pick: Array[DoorOption] = _roller(table, [REWARD_HIT, 1]).roll_doors(TEST_ROOM)
	var second_pick: Array[DoorOption] = _roller(table, [REWARD_HIT, 2]).roll_doors(TEST_ROOM)

	assert_eq(first_pick[0].reward, TREASURE)
	assert_eq(second_pick[0].reward, HEALING_SPRING)


func test_reward_goes_to_the_door_with_more_enemy_hit_points(
	params: Array = use_parameters(HARDEST_DOOR_CASES)
) -> void:
	var weak: EncounterData = _encounter([8])
	var strong: EncounterData = _encounter([7, 9])
	var table: RoomTableData = _table([weak, strong], _treasure_only())

	var doors: Array[DoorOption] = _roller(table, [params[0], REWARD_HIT]).roll_doors(TEST_ROOM)

	var reward_index: int = params[1]
	assert_eq(doors[reward_index].encounter, strong)
	assert_eq(doors[reward_index].reward, TREASURE)
	assert_null(doors[1 - reward_index].reward, "Only one door gets a reward")


func test_reward_goes_to_the_first_door_on_a_tie() -> void:
	var table: RoomTableData = _table([_encounter([8]), _encounter([3, 5])], _treasure_only())

	var doors: Array[DoorOption] = _roller(table, [2, REWARD_HIT]).roll_doors(TEST_ROOM)

	assert_eq(doors[0].reward, TREASURE)
	assert_null(doors[1].reward)


func test_no_rewards_need_no_chance_roll() -> void:
	var no_rewards: Array[DoorRewardData] = []
	var table: RoomTableData = _table([_encounter([8])], no_rewards)

	var doors: Array[DoorOption] = _roller(table, []).roll_doors(TEST_ROOM)

	assert_eq(_rewards_of(doors), [null, null] as Array[DoorRewardData])


func test_room_without_encounters_reports_an_error_and_has_no_doors() -> void:
	var no_encounters: Array[EncounterData] = []
	var table: RoomTableData = _table(no_encounters, _treasure_only())

	var doors: Array[DoorOption] = _roller(table, []).roll_doors(TEST_ROOM)

	assert_push_error_count(1, "One error, not one per door")
	assert_eq(doors.size(), 0)


func test_elite_room_doors_are_elite() -> void:
	var doors: Array[DoorOption] = _roller(ROOM_TABLE, [1, REWARD_MISS]).roll_doors(ELITE_ROOM)

	assert_eq(doors[0].enemies[0].display_name, "Elite Skeleton")
	assert_eq(doors[0].enemies[0].max_hit_points, 18, "13 HP + 10% scaling + 30% elite")
	assert_eq(doors[1].enemies[0].display_name, "Elite Orc")
	assert_eq(doors[1].enemies[0].get_attack_bonus(), 7, "+5, +1 scaling and +1 elite")


func test_door_enemies_are_scaled_to_the_room() -> void:
	# Room 8: d6 = 1 picks the Guardian, d5 = 1 the Guardian with a Goblin.
	var doors: Array[DoorOption] = _roller(ROOM_TABLE, [1, 1, REWARD_MISS]).roll_doors(8)

	var guardian: Combatant = doors[0].enemies[0]
	assert_eq(guardian.display_name, "Guardian")
	assert_eq(guardian.get_attack_bonus(), 5, "+3 and two steps of +1")
	assert_eq(guardian.max_hit_points, 26, "22 HP + 20% = 26.4 rounds down")
	assert_eq(doors[1].enemies.size(), 2)
	assert_eq(doors[1].enemies[1].max_hit_points, 10, "8 HP + 20% = 9.6 rounds up")


func test_every_door_room_rolls_distinct_doors_with_living_enemies() -> void:
	for seed_value: int in SEED_COUNT:
		var roller: DoorRoller = DoorRoller.new(DiceRoller.new(seed_value), ROOM_TABLE)
		for room: int in range(2, GAME_RULES.room_count):
			var doors: Array[DoorOption] = roller.roll_doors(room)
			var where: String = "seed %d, room %d" % [seed_value, room]
			assert_eq(doors.size(), ROOM_TABLE.doors_per_room, where)
			assert_ne(doors[0].encounter, doors[1].encounter, where)
			assert_gte(_rewards_of(doors).count(null), doors.size() - 1, "%s: one reward" % where)
			for door: DoorOption in doors:
				assert_between(door.enemies.size(), 1, MAX_ENEMIES_PER_ENCOUNTER, where)
				for enemy: Combatant in door.enemies:
					assert_true(enemy.is_alive(), "%s: %s" % [where, enemy.display_name])
