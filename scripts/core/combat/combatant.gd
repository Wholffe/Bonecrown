@abstract class_name Combatant
extends RefCounted
## A participant in a fight: the player character or an enemy.

var display_name: String
var max_hit_points: int
var hit_points: int

@abstract func get_armor_class() -> int
@abstract func get_attack_bonus() -> int
@abstract func get_crit_threshold() -> int
@abstract func get_damage_die_count() -> int
@abstract func get_damage_die_sides() -> int
@abstract func get_damage_bonus() -> int


func is_alive() -> bool:
	return hit_points > 0


func take_damage(amount: int) -> void:
	assert(amount >= 0, "Damage must not be negative")
	hit_points = maxi(hit_points - amount, 0)
