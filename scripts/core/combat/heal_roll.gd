class_name HealRoll
extends RefCounted
## Outcome of one healing roll: the single dice results, their die and the flat bonus.

var dice_results: Array[int] = []
var die_sides: int
var heal_bonus: int
var total: int


func _init(results: Array[int], sides: int, bonus: int) -> void:
	dice_results = results
	die_sides = sides
	heal_bonus = bonus
	total = bonus
	for result: int in results:
		total += result
