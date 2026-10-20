class_name AttackRoll
extends RefCounted
## Outcome of one d20 attack roll against an armor class.

## ADVANTAGE rolls two d20 and keeps the higher, DISADVANTAGE keeps the lower.
enum RollMode { NORMAL, ADVANTAGE, DISADVANTAGE }

const DIE_SIDES: int = 20
const AUTOMATIC_MISS: int = 1
## A normal hit whose total exceeds the armor class by at most this much counts as narrow.
const NARROW_HIT_MARGIN: int = 1

## The kept d20. Natural 1, natural 20 and crits only look at this die.
var natural_roll: int
var roll_mode: RollMode
## The d20 that advantage or disadvantage did not keep, 0 for a normal roll.
var discarded_roll: int
var attack_bonus: int
var target_armor_class: int
var total: int
var is_natural_one: bool
var is_natural_twenty: bool
var is_crit: bool
var is_hit: bool
var is_narrow_hit: bool


func _init(
	roll: int,
	bonus: int,
	armor_class: int,
	crit_threshold: int,
	mode: RollMode = RollMode.NORMAL,
	other_roll: int = 0
) -> void:
	assert(roll >= 1 and roll <= DIE_SIDES, "Natural roll must be a d20 result")
	assert(
		(mode == RollMode.NORMAL) == (other_roll == 0),
		"Only advantage and disadvantage have a second d20"
	)
	assert(
		crit_threshold > AUTOMATIC_MISS and crit_threshold <= DIE_SIDES,
		"Crit threshold must lie between 2 and 20"
	)
	natural_roll = roll
	roll_mode = mode
	discarded_roll = other_roll
	attack_bonus = bonus
	target_armor_class = armor_class
	total = roll + bonus
	is_natural_one = roll == AUTOMATIC_MISS
	is_natural_twenty = roll == DIE_SIDES
	is_crit = roll >= crit_threshold
	is_hit = is_crit or (not is_natural_one and total >= armor_class)
	is_narrow_hit = is_hit and not is_crit and total - armor_class <= NARROW_HIT_MARGIN
