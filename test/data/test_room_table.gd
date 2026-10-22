extends GutTest
## Content rules of the room table: tiers, encounters, the elite room, the scaling values, the doors
## and the boss room.

const ROOM_TABLE: RoomTableData = preload("res://scripts/data/rooms/room_table.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const FIRST_ROOM: int = 1
const MAX_ENEMIES_PER_ENCOUNTER: int = 3


## Every room before the boss room is a fight room.
func _last_fight_room() -> int:
	return GAME_RULES.room_count - 1


func _tiers_covering(room: int) -> int:
	var count: int = 0
	for tier: RoomTierData in ROOM_TABLE.tiers:
		if room >= tier.first_room and room <= tier.last_room:
			count += 1
	return count


func _all_encounters() -> Array[EncounterData]:
	var encounters: Array[EncounterData] = []
	for tier: RoomTierData in ROOM_TABLE.tiers:
		encounters.append_array(tier.encounters)
	encounters.append_array(ROOM_TABLE.elite_encounters)
	return encounters


func test_tiers_have_no_empty_slots() -> void:
	assert_false(ROOM_TABLE.tiers.is_empty(), "The room table has no tiers")
	assert_does_not_have(ROOM_TABLE.tiers, null)


func test_tiers_cover_every_fight_room_exactly_once() -> void:
	for room: int in range(FIRST_ROOM, _last_fight_room() + 1):
		assert_eq(_tiers_covering(room), 1, "room %d" % room)


func test_tiers_stay_within_the_fight_rooms() -> void:
	for tier: RoomTierData in ROOM_TABLE.tiers:
		var rooms: String = "rooms %d to %d" % [tier.first_room, tier.last_room]
		assert_gte(tier.first_room, FIRST_ROOM, rooms)
		assert_lte(tier.first_room, tier.last_room, rooms)
		assert_lte(tier.last_room, _last_fight_room(), rooms)


func test_tiers_have_encounters() -> void:
	for tier: RoomTierData in ROOM_TABLE.tiers:
		var rooms: String = "rooms %d to %d" % [tier.first_room, tier.last_room]
		assert_false(tier.encounters.is_empty(), "%s have no encounters" % rooms)
		assert_does_not_have(tier.encounters, null, "%s have an empty encounter slot" % rooms)


func test_encounters_have_one_to_three_enemies() -> void:
	for encounter: EncounterData in _all_encounters():
		var path: String = encounter.resource_path
		assert_between(encounter.enemies.size(), 1, MAX_ENEMIES_PER_ENCOUNTER, path)
		assert_does_not_have(encounter.enemies, null, "%s has an empty enemy slot" % path)


func test_elite_room_lies_inside_the_tiers() -> void:
	assert_eq(_tiers_covering(ROOM_TABLE.elite_room), 1, "room %d" % ROOM_TABLE.elite_room)


func test_elite_encounters_have_exactly_one_enemy() -> void:
	assert_false(ROOM_TABLE.elite_encounters.is_empty(), "The elite room has no encounters")
	for encounter: EncounterData in ROOM_TABLE.elite_encounters:
		assert_eq(encounter.enemies.size(), 1, encounter.resource_path)


func test_elite_bonuses_are_positive() -> void:
	assert_ne(ROOM_TABLE.elite_name_prefix, "", "elite_name_prefix")
	assert_gt(ROOM_TABLE.elite_hit_point_percent, 0, "elite_hit_point_percent")
	assert_gt(ROOM_TABLE.elite_attack_bonus, 0, "elite_attack_bonus")
	assert_gt(ROOM_TABLE.elite_loot_bonus, 0, "elite_loot_bonus")


# The step divides the room number, so it must not be 0.
func test_scaling_values_are_positive() -> void:
	assert_gt(ROOM_TABLE.scaling_room_step, 0, "scaling_room_step")
	assert_gt(ROOM_TABLE.scaling_attack_bonus, 0, "scaling_attack_bonus")
	assert_gt(ROOM_TABLE.scaling_hit_point_percent, 0, "scaling_hit_point_percent")


func test_first_room_has_no_door_choice() -> void:
	assert_gt(ROOM_TABLE.first_door_room, FIRST_ROOM, "first_door_room")
	assert_lte(ROOM_TABLE.first_door_room, _last_fight_room(), "first_door_room")


func test_door_values_are_positive() -> void:
	assert_gt(ROOM_TABLE.doors_per_room, 1, "doors_per_room: a choice needs two doors")
	assert_between(ROOM_TABLE.door_reward_chance_percent, 1, 100, "door_reward_chance_percent")
	assert_false(ROOM_TABLE.door_rewards.is_empty(), "The doors have no rewards")
	assert_does_not_have(ROOM_TABLE.door_rewards, null, "door_rewards has an empty slot")


func test_boss_room_is_the_last_room_of_the_run() -> void:
	assert_eq(ROOM_TABLE.boss_room, GAME_RULES.room_count)


func test_boss_encounter_has_exactly_one_enemy() -> void:
	assert_not_null(ROOM_TABLE.boss_encounter, "The boss room has no encounter")
	assert_eq(ROOM_TABLE.boss_encounter.enemies.size(), 1)
	assert_does_not_have(ROOM_TABLE.boss_encounter.enemies, null)
