extends Node
## Autoload that holds the current run: seed, dice, player character, room number and chosen door.

const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
const ROOM_TABLE: RoomTableData = preload("res://scripts/data/rooms/room_table.tres")
const FIRST_ROOM: int = 1

var run_seed: int
var dice: DiceRoller
var player: Character
var room_number: int = FIRST_ROOM
## The door the player chose for the current room, or null. Cleared when the room changes.
var chosen_door: DoorOption = null


func start_new_run(class_data: ClassData, seed_value: int) -> void:
	run_seed = seed_value
	dice = DiceRoller.new(seed_value)
	player = Character.new(class_data, GAME_RULES)
	room_number = FIRST_ROOM
	chosen_door = null


## The rewards for the room just won, with the reward of the chosen door.
## The caller shows them and then calls advance_room().
func start_room_rewards() -> RoomRewards:
	var room_loot_bonus: int = _encounter_roller().loot_bonus(room_number)
	var door_reward: DoorRewardData = chosen_door.reward if chosen_door != null else null
	return RoomRewards.new(player, room_number, room_loot_bonus, dice, LOOT_TABLE, door_reward)


## The enemies behind the chosen door, else enemies rolled for the current room and scaled to it.
func create_room_enemies() -> Array[Combatant]:
	if chosen_door != null:
		return chosen_door.enemies
	return _encounter_roller().roll_enemies(room_number)


## Whether the player picks a door before the fight of the current room.
func is_door_room() -> bool:
	return _door_roller().has_doors(room_number)


## The doors of the current room. The caller shows them and calls choose_door() with one.
func roll_doors() -> Array[DoorOption]:
	return _door_roller().roll_doors(room_number)


func choose_door(door: DoorOption) -> void:
	chosen_door = door


func advance_room() -> void:
	room_number += 1
	chosen_door = null


## The last room of the run holds the boss.
func is_boss_room() -> bool:
	return room_number == GAME_RULES.room_count


## The only place that uses unseeded randomness: picking the seed of a new run.
func new_random_seed() -> int:
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	return seed_source.randi()


# Built on demand, so it always rolls with the current dice (tests replace them after a new run).
func _encounter_roller() -> EncounterRoller:
	return EncounterRoller.new(dice, ROOM_TABLE)


# Built on demand for the same reason as _encounter_roller().
func _door_roller() -> DoorRoller:
	return DoorRoller.new(dice, ROOM_TABLE)
