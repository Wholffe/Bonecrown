class_name DiceRoller
extends RefCounted
## Seeded dice roller. All game randomness goes through this class, so runs are reproducible.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


func roll(sides: int) -> int:
	assert(sides >= 1, "A die needs at least one side")
	return _rng.randi_range(1, sides)


func roll_many(count: int, sides: int) -> Array[int]:
	var results: Array[int] = []
	for _i: int in count:
		results.append(roll(sides))
	return results
