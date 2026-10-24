extends GutTest
## EncounterRoller: encounters by room tier, elite fights, room scaling, the elite loot bonus and
## the boss room.

const ROOM_TABLE: RoomTableData = preload("res://scripts/data/rooms/room_table.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const SKELETON: EnemyData = preload("res://scripts/data/enemies/skeleton.tres")
const BONE_KING: EnemyData = preload("res://scripts/data/enemies/bone_king.tres")
const FIRST_ROOM: int = 1
const ELITE_ROOM: int = 5
const ELITE_LOOT_BONUS: int = 3
## Handed to FixedDice where no roll is expected, so a roll shows up in remaining_rolls().
const SPARE_ROLL: int = 1
const MAX_ENEMIES_PER_ENCOUNTER: int = 3
const SEED: int = 4711
const ROLL_COUNT: int = 20
## [room, roll, display names] in the room table's tiers of rooms 2–3, 4–6 and 7–9.
const TIER_PICK_CASES: Array = [
	[2, 1, ["Goblin 1", "Goblin 2"]],
	[3, 2, ["Goblin"]],
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
## [roll, display name, attack bonus, max hit points] of an elite fight in room 5: one scaling
## step (+1 attack, +10% HP) plus the elite bonuses (+1 attack, +30% HP).
const ELITE_CASES: Array = [
	[1, "Elite Skeleton", 6, 18],
	[2, "Elite Orc", 7, 28],
	[3, "Elite Guardian", 5, 31],
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


func test_elite_fight_picks_from_the_elite_pool_by_one_roll(
	params: Array = use_parameters(ELITE_CASES)
) -> void:
	var enemies: Array[Combatant] = _roller([params[0]]).roll_enemies(ELITE_ROOM, true)

	assert_eq(_display_names(enemies), [params[1]] as Array[String])
	assert_eq(_dice.remaining_rolls(), 0)


func test_elite_bonuses_add_to_the_room_scaling(
	params: Array = use_parameters(ELITE_CASES)
) -> void:
	var enemy: Combatant = _roller([params[0]]).roll_enemies(ELITE_ROOM, true)[0]

	assert_eq(enemy.get_attack_bonus(), params[2], "%s attack" % params[1])
	assert_eq(enemy.max_hit_points, params[3], "%s hit points" % params[1])
	assert_eq(enemy.hit_points, enemy.max_hit_points, "%s full health" % params[1])


func test_elite_enemy_leaves_shared_data_untouched() -> void:
	_roller([1]).roll_enemies(ELITE_ROOM, true)

	assert_eq(SKELETON.display_name, "Skeleton")
	assert_eq(SKELETON.attack_bonus, 4)
	assert_eq(SKELETON.max_hit_points, 13)


func test_only_elite_fights_add_a_loot_bonus() -> void:
	var roller: EncounterRoller = _roller([])

	assert_eq(roller.loot_bonus(true), ELITE_LOOT_BONUS)
	assert_eq(roller.loot_bonus(false), 0)


func test_normal_fight_in_room_five_draws_from_its_tier() -> void:
	var enemies: Array[Combatant] = _roller([1]).roll_enemies(ELITE_ROOM)

	assert_eq(_display_names(enemies), ["Skeleton"] as Array[String])


func test_room_without_a_tier_reports_an_error() -> void:
	var room_after_the_run: int = GAME_RULES.room_count + 1

	var enemies: Array[Combatant] = _roller([SPARE_ROLL]).roll_enemies(room_after_the_run)

	assert_push_error_count(1, "No tier covers a room after the boss room")
	assert_eq(enemies.size(), 0)
	assert_eq(_dice.remaining_rolls(), 1)


func test_boss_room_has_the_unscaled_boss_without_rolling() -> void:
	var enemies: Array[Combatant] = _roller([SPARE_ROLL]).roll_enemies(GAME_RULES.room_count)

	assert_eq(enemies.size(), 1)
	var boss: Enemy = enemies[0] as Enemy
	assert_eq(boss.data, BONE_KING)
	assert_eq(boss.display_name, BONE_KING.display_name, "No elite prefix and no number")
	assert_eq(boss.get_attack_bonus(), BONE_KING.attack_bonus, "No room scaling on the attack")
	assert_eq(boss.max_hit_points, BONE_KING.max_hit_points, "No room scaling on the hit points")
	assert_eq(_dice.remaining_rolls(), 1, "The boss room needs no roll")


func test_boss_room_without_a_boss_encounter_reports_an_error() -> void:
	var table: RoomTableData = _scaling_table()
	table.boss_room = 10
	_dice = FixedDice.new([])

	var enemies: Array[Combatant] = EncounterRoller.new(_dice, table).roll_enemies(10)

	assert_push_error_count(1, "The boss room has no boss encounter")
	assert_eq(enemies.size(), 0)


func test_every_fight_room_rolls_one_to_three_living_enemies() -> void:
	var roller: EncounterRoller = EncounterRoller.new(DiceRoller.new(SEED), ROOM_TABLE)

	for _i: int in ROLL_COUNT:
		for room: int in range(FIRST_ROOM, GAME_RULES.room_count):
			var enemies: Array[Combatant] = roller.roll_enemies(room)
			assert_between(enemies.size(), 1, MAX_ENEMIES_PER_ENCOUNTER, "room %d" % room)
			for enemy: Combatant in enemies:
				assert_true(enemy.is_alive(), "%s in room %d" % [enemy.display_name, room])
