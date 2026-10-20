extends Node
## Autoload that holds the current run: seed, dice, player character, room number, enemy knowledge.

const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
const FIRST_ROOM: int = 1
## Until the room data of milestone 7 exists, no room adds its own loot bonus.
const ROOM_LOOT_BONUS: int = 0

var run_seed: int
var dice: DiceRoller
var player: Character
var room_number: int = FIRST_ROOM
var enemy_knowledge: EnemyKnowledge


func start_new_run(class_data: ClassData, seed_value: int) -> void:
	run_seed = seed_value
	dice = DiceRoller.new(seed_value)
	player = Character.new(class_data, GAME_RULES)
	room_number = FIRST_ROOM
	enemy_knowledge = EnemyKnowledge.new()


## The rewards for the room just won. The caller shows them and then calls advance_room().
func start_room_rewards() -> RoomRewards:
	return RoomRewards.new(player, room_number, ROOM_LOOT_BONUS, dice, LOOT_TABLE)


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
