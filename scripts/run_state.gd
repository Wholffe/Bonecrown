extends Node
## Autoload that holds the current run: seed, dice, player character and room number.

const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
const ROOM_TABLE: RoomTableData = preload("res://scripts/data/rooms/room_table.tres")
const FIRST_ROOM: int = 1

var run_seed: int
var dice: DiceRoller
var player: Character
var room_number: int = FIRST_ROOM


func start_new_run(class_data: ClassData, seed_value: int) -> void:
	run_seed = seed_value
	dice = DiceRoller.new(seed_value)
	player = Character.new(class_data, GAME_RULES)
	room_number = FIRST_ROOM


## The rewards for the room just won. The caller shows them and then calls advance_room().
func start_room_rewards() -> RoomRewards:
	var room_loot_bonus: int = _encounter_roller().loot_bonus(room_number)
	return RoomRewards.new(player, room_number, room_loot_bonus, dice, LOOT_TABLE)


## The enemies of the current room, scaled to it.
func create_room_enemies() -> Array[Combatant]:
	return _encounter_roller().roll_enemies(room_number)


func advance_room() -> void:
	room_number += 1


## Until the boss of milestone 10 exists, winning this room completes the run.
func is_last_fight_room() -> bool:
	return room_number >= GAME_RULES.room_count - 1


## The only place that uses unseeded randomness: picking the seed of a new run.
func new_random_seed() -> int:
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	return seed_source.randi()


# Built on demand, so it always rolls with the current dice (tests replace them after a new run).
func _encounter_roller() -> EncounterRoller:
	return EncounterRoller.new(dice, ROOM_TABLE)
