extends Node
## Autoload that holds the current run: seed, dice, player character and room number.

const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const FIRST_ROOM: int = 1

var run_seed: int
var dice: DiceRoller
var player: Character
var room_number: int = FIRST_ROOM


func start_new_run(class_data: ClassData, seed_value: int) -> void:
	run_seed = seed_value
	dice = DiceRoller.new(seed_value)
	player = Character.new(class_data, GAME_RULES.proficiency_bonus)
	room_number = FIRST_ROOM


## The only place that uses unseeded randomness: picking the seed of a new run.
func new_random_seed() -> int:
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	return seed_source.randi()
