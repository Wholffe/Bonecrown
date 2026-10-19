class_name AttackRoll
extends RefCounted
## Outcome of one d20 attack roll against an armor class.

const DIE_SIDES: int = 20
const AUTOMATIC_MISS: int = 1

var natural_roll: int
var attack_bonus: int
var target_armor_class: int
var total: int
var is_natural_one: bool
var is_natural_twenty: bool
var is_crit: bool
var is_hit: bool


func _init(roll: int, bonus: int, armor_class: int, crit_threshold: int) -> void:
	assert(roll >= 1 and roll <= DIE_SIDES, "Natural roll must be a d20 result")
	assert(
		crit_threshold > AUTOMATIC_MISS and crit_threshold <= DIE_SIDES,
		"Crit threshold must lie between 2 and 20"
	)
	natural_roll = roll
	attack_bonus = bonus
	target_armor_class = armor_class
	total = roll + bonus
	is_natural_one = roll == AUTOMATIC_MISS
	is_natural_twenty = roll == DIE_SIDES
	is_crit = roll >= crit_threshold
	is_hit = is_crit or (not is_natural_one and total >= armor_class)
