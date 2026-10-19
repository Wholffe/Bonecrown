class_name HealRoll
extends RefCounted
## Outcome of one healing roll: the single dice results plus the flat bonus.

var dice_results: Array[int] = []
var heal_bonus: int
var total: int


func _init(results: Array[int], bonus: int) -> void:
	dice_results = results
	heal_bonus = bonus
	total = bonus
	for result: int in results:
		total += result
