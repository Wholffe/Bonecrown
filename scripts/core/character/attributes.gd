class_name Attributes
extends RefCounted
## The four combat and loot attributes of a character and their 5e-style bonuses.

# Stored as numbers in .tres files (skill checks): append new members, never renumber.
enum Kind { STRENGTH = 0, DEXTERITY = 1, CONSTITUTION = 2, LUCK = 3, UNSET = -1 }

const NEUTRAL_VALUE: int = 10
const POINTS_PER_BONUS: float = 2.0

var _values: Dictionary[Kind, int] = {}


func _init(strength: int, dexterity: int, constitution: int, luck: int) -> void:
	_values[Kind.STRENGTH] = strength
	_values[Kind.DEXTERITY] = dexterity
	_values[Kind.CONSTITUTION] = constitution
	_values[Kind.LUCK] = luck


static func bonus_for(value: int) -> int:
	# Float division, because integer division truncates toward zero (9 would give 0, not -1).
	return floori((value - NEUTRAL_VALUE) / POINTS_PER_BONUS)


func value_of(kind: Kind) -> int:
	return _values[kind]


func bonus_of(kind: Kind) -> int:
	return bonus_for(_values[kind])
