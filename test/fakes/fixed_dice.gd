class_name FixedDice
extends DiceRoller
## Test fake that returns a fixed sequence of rolls instead of random ones.

var _rolls: Array[int] = []
var _next_index: int = 0


func _init(rolls: Array[int]) -> void:
	super(0)
	_rolls = rolls


func roll(sides: int) -> int:
	assert(_next_index < _rolls.size(), "FixedDice ran out of rolls")
	var result: int = _rolls[_next_index]
	assert(result >= 1 and result <= sides, "Fixed roll %d does not fit a d%d" % [result, sides])
	_next_index += 1
	return result


func remaining_rolls() -> int:
	return _rolls.size() - _next_index
