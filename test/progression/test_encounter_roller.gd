extends GutTest
## EncounterRoller: encounters by room tier, the elite room, room scaling and the room loot bonus.

const ROOM_TABLE: RoomTableData = preload("res://scripts/data/rooms/room_table.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const SKELETON: EnemyData = preload("res://scripts/data/enemies/skeleton.tres")
const FIRST_ROOM: int = 1
const ELITE_ROOM: int = 5
const ELITE_LOOT_BONUS: int = 3
## Handed to FixedDice where no roll is expected, so a roll shows up in remaining_rolls().
const SPARE_ROLL: int = 1
const MAX_ENEMIES_PER_ENCOUNTER: int = 3
const SEED: int = 4711
const ROLL_COUNT: int = 20
## [room] of the room table's tier of rooms 2–3.
const GOBLIN_PAIR_ROOM_CASES: Array = [[2], [3]]
## [room, roll, display names] in the room table's tiers of rooms 4–6 and 7–9.
const TIER_PICK_CASES: Array = [
	[4, 1, ["Skeleton"]],
	[4, 2, ["Orc"]],
	[6, 5, ["Skeleton 1", "Skeleton 2"]],
	[7, 1, ["Guardian"]],
	[9, 6, ["Orc", "Goblin 1", "Goblin 2"]],
]
## [room, attack bonus, max hit points] of a +0 attack, 15 HP enemy in _scaling_table().
## Room 4 checks the rounding: 15 HP + 10% = 16.5 rounds up.
const SCALING_CASES: Array = [
	[1, 0, 15],
	[3, 0, 15],
	[4, 1, 17],
	[6, 1, 17],
	[7, 2, 18],
	[9, 2, 18],
]
## [roll, display name, attack bonus, max hit points] in the elite room: room 5 is one scaling
## step (+1 attack, +10% HP) plus the elite bonuses (+1 attack, +30% HP).
const ELITE_CASES: Array = [
	[1, "Elite Skeleton", 6, 18],
	[2, "Elite Orc", 7, 28],
]

var _dice: FixedDice


func _roller(rolls: Array[int]) -> EncounterRoller:
	_dice = FixedDice.new(rolls)
	return EncounterRoller.new(_dice, ROOM_TABLE)


func _display_names(enemies: Array[Combatant]) -> Array[String]:
	var names: Array[String] = []
	for enemy: Combatant in enemies:
		names.append(enemy.display_name)
	return names


## One tier over rooms 1 to 9 with a single encounter, scaled every 3 rooms by +1 attack and +10%
## hit points, and no elite room among the fight rooms.
func _scaling_table() -> RoomTableData:
	var enemy_data: EnemyData = EnemyData.new()
	enemy_data.id = &"test_enemy"
	enemy_data.display_name = "Test Enemy"
	enemy_data.max_hit_points = 15
	var encounter: EncounterData = EncounterData.new()
	encounter.enemies = [enemy_data]
	var tier: RoomTierData = RoomTierData.new()
	tier.first_room = 1
	tier.last_room = 9
	tier.encounters = [encounter]
	var table: RoomTableData = RoomTableData.new()
	table.tiers = [tier]
	table.scaling_room_step = 3
	table.scaling_attack_bonus = 1
	table.scaling_hit_point_percent = 10
	return table


func test_first_room_has_one_goblin_without_rolling() -> void:
	var enemies: Array[Combatant] = _roller([SPARE_ROLL]).roll_enemies(FIRST_ROOM)

	assert_eq(_display_names(enemies), ["Goblin"] as Array[String])
	assert_eq(_dice.remaining_rolls(), 1, "A pool of one encounter needs no roll")


func test_rooms_two_and_three_have_two_goblins_without_rolling(
	params: Array = use_parameters(GOBLIN_PAIR_ROOM_CASES)
) -> void:
	var enemies: Array[Combatant] = _roller([SPARE_ROLL]).roll_enemies(params[0])

	assert_eq(_display_names(enemies), ["Goblin 1", "Goblin 2"] as Array[String])
	assert_eq(_dice.remaining_rolls(), 1, "A pool of one encounter needs no roll")


func test_tier_room_picks_the_encounter_by_one_roll(
	params: Array = use_parameters(TIER_PICK_CASES)
) -> void:
	var expected: Array[String] = []
	expected.assign(params[2])

	var enemies: Array[Combatant] = _roller([params[1]]).roll_enemies(params[0])

	assert_eq(_display_names(enemies), expected, "room %d, roll %d" % [params[0], params[1]])
	assert_eq(_dice.remaining_rolls(), 0)


func test_scaling_raises_attack_and_hit_points_every_step(
	params: Array = use_parameters(SCALING_CASES)
) -> void:
	_dice = FixedDice.new([])
	var roller: EncounterRoller = EncounterRoller.new(_dice, _scaling_table())

	var enemy: Combatant = roller.roll_enemies(params[0])[0]

	assert_eq(enemy.get_attack_bonus(), params[1], "room %d attack" % params[0])
	assert_eq(enemy.max_hit_points, params[2], "room %d hit points" % params[0])
	assert_eq(enemy.hit_points, enemy.max_hit_points, "room %d full health" % params[0])


func test_room_table_scales_room_eight_by_two_steps() -> void:
	var enemies: Array[Combatant] = _roller([2]).roll_enemies(8)

	assert_eq(_display_names(enemies), ["Guardian", "Goblin"] as Array[String])
	assert_eq(enemies[0].get_attack_bonus(), 5, "+3 and two steps of +1")
	assert_eq(enemies[0].max_hit_points, 26, "22 HP + 20% = 26.4 rounds down")
	assert_eq(enemies[1].get_attack_bonus(), 5, "+3 and two steps of +1")
	assert_eq(enemies[1].max_hit_points, 10, "8 HP + 20% = 9.6 rounds up")


func test_elite_room_picks_from_the_elite_pool_by_one_roll(
	params: Array = use_parameters(ELITE_CASES)
) -> void:
	var enemies: Array[Combatant] = _roller([params[0]]).roll_enemies(ELITE_ROOM)

	assert_eq(_display_names(enemies), [params[1]] as Array[String])
	assert_eq(_dice.remaining_rolls(), 0)


func test_elite_bonuses_add_to_the_room_scaling(
	params: Array = use_parameters(ELITE_CASES)
) -> void:
	var enemy: Combatant = _roller([params[0]]).roll_enemies(ELITE_ROOM)[0]

	assert_eq(enemy.get_attack_bonus(), params[2], "%s attack" % params[1])
	assert_eq(enemy.max_hit_points, params[3], "%s hit points" % params[1])
	assert_eq(enemy.hit_points, enemy.max_hit_points, "%s full health" % params[1])


func test_elite_enemy_leaves_shared_data_untouched() -> void:
	_roller([1]).roll_enemies(ELITE_ROOM)

	assert_eq(SKELETON.display_name, "Skeleton")
	assert_eq(SKELETON.attack_bonus, 4)
	assert_eq(SKELETON.max_hit_points, 13)


func test_only_the_elite_room_adds_a_loot_bonus() -> void:
	var roller: EncounterRoller = _roller([])

	for room: int in range(FIRST_ROOM, GAME_RULES.room_count):
		var expected: int = ELITE_LOOT_BONUS if room == ELITE_ROOM else 0
		assert_eq(roller.loot_bonus(room), expected, "room %d" % room)


func test_room_without_a_tier_reports_an_error() -> void:
	var boss_room: int = GAME_RULES.room_count

	var enemies: Array[Combatant] = _roller([SPARE_ROLL]).roll_enemies(boss_room)

	assert_push_error_count(1, "The boss room has no tier in the room table")
	assert_eq(enemies.size(), 0)
	assert_eq(_dice.remaining_rolls(), 1)


func test_every_fight_room_rolls_one_to_three_living_enemies() -> void:
	var roller: EncounterRoller = EncounterRoller.new(DiceRoller.new(SEED), ROOM_TABLE)

	for _i: int in ROLL_COUNT:
		for room: int in range(FIRST_ROOM, GAME_RULES.room_count):
			var enemies: Array[Combatant] = roller.roll_enemies(room)
			assert_between(enemies.size(), 1, MAX_ENEMIES_PER_ENCOUNTER, "room %d" % room)
			for enemy: Combatant in enemies:
				assert_true(enemy.is_alive(), "%s in room %d" % [enemy.display_name, room])
