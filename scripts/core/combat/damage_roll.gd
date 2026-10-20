class_name DamageRoll
extends RefCounted
## Outcome of one damage roll: the single dice results plus the flat bonus, less the defender's
## damage reduction.

const MINIMUM_DAMAGE: int = 1

var dice_results: Array[int] = []
var damage_bonus: int
## Dice plus bonus before the damage reduction. Drain heals half of this.
var rolled_total: int
var damage_reduction: int
## Damage the defender takes.
var total: int


func _init(results: Array[int], bonus: int, reduction: int = 0) -> void:
	assert(reduction >= 0, "Damage reduction must not be negative")
	dice_results = results
	damage_bonus = bonus
	damage_reduction = reduction
	var dice_sum: int = 0
	for result: int in results:
		dice_sum += result
	rolled_total = maxi(dice_sum + bonus, MINIMUM_DAMAGE)
	total = maxi(rolled_total - reduction, MINIMUM_DAMAGE)
