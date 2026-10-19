class_name DamageRoll
extends RefCounted
## Outcome of one damage roll: the single dice results plus the flat bonus.

const MINIMUM_DAMAGE: int = 1

var dice_results: Array[int] = []
var damage_bonus: int
var total: int


func _init(results: Array[int], bonus: int) -> void:
	dice_results = results
	damage_bonus = bonus
	var dice_sum: int = 0
	for result: int in results:
		dice_sum += result
	total = maxi(dice_sum + bonus, MINIMUM_DAMAGE)
