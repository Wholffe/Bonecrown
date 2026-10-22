class_name DoorRoller
extends RefCounted
## Rolls the doors before a fight: an encounter behind each door and maybe a reward on the hardest.

const PERCENT_DIE_SIDES: int = 100

var _dice: DiceRoller
var _table: RoomTableData
var _encounter_roller: EncounterRoller


func _init(dice: DiceRoller, table: RoomTableData) -> void:
	_dice = dice
	_table = table
	_encounter_roller = EncounterRoller.new(dice, table)


## The rooms before first_door_room and the boss room start their fight without a door choice.
func has_doors(room_number: int) -> bool:
	return room_number >= _table.first_door_room and room_number != _table.boss_room


## Each door draws another encounter while the room's pool has one left, so doors only repeat
## an encounter in a small pool. A room without encounters is a data error and gives no doors.
func roll_doors(room_number: int) -> Array[DoorOption]:
	var doors: Array[DoorOption] = []
	var picked: Array[EncounterData] = []
	for _i: int in _table.doors_per_room:
		var encounter: EncounterData = _encounter_roller.pick_encounter(room_number, picked)
		if encounter == null:
			return doors
		picked.append(encounter)
		var enemies: Array[Combatant] = _encounter_roller.create_enemies(encounter, room_number)
		doors.append(DoorOption.new(encounter, enemies))
	_place_reward(doors)
	return doors


## With door_reward_chance_percent, the door with the most enemy hit points (the first of them on
## a tie) gets a reward picked from door_rewards. The harder fight carries the reward.
func _place_reward(doors: Array[DoorOption]) -> void:
	if doors.is_empty() or _table.door_rewards.is_empty():
		return
	if _dice.roll(PERCENT_DIE_SIDES) > _table.door_reward_chance_percent:
		return
	var reward: DoorRewardData = _table.door_rewards[0]
	if _table.door_rewards.size() > 1:
		reward = _table.door_rewards[_dice.roll(_table.door_rewards.size()) - 1]
	var hardest: DoorOption = doors[0]
	for door: DoorOption in doors:
		if _base_hit_points(door.encounter) > _base_hit_points(hardest.encounter):
			hardest = door
	hardest.reward = reward


# The data values, because every door of a room gets the same scaling.
func _base_hit_points(encounter: EncounterData) -> int:
	var total: int = 0
	for enemy_data: EnemyData in encounter.enemies:
		total += enemy_data.max_hit_points
	return total
