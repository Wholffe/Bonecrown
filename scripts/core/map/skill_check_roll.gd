class_name SkillCheckRoll
extends RefCounted
## Outcome of one skill check: the d20 plus the attribute bonus against the check's difficulty.

const DIE_SIDES: int = 20

var natural_roll: int
var attribute_bonus: int
var total: int
var difficulty: int
var is_success: bool


func _init(roll: int, bonus: int, check_difficulty: int) -> void:
	assert(roll >= 1 and roll <= DIE_SIDES, "Natural roll must be a d20 result")
	natural_roll = roll
	attribute_bonus = bonus
	total = roll + bonus
	difficulty = check_difficulty
	is_success = total >= difficulty
