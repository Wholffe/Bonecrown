@abstract class_name Combatant
extends RefCounted
## A participant in a fight: the player character or an enemy.

var display_name: String
var max_hit_points: int
var hit_points: int
## Pays for actions in a fight. Combat sets it at the start of every fight.
var momentum: int = 0

@abstract func get_armor_class() -> int
@abstract func get_attack_bonus() -> int
@abstract func get_crit_threshold() -> int
@abstract func get_damage_die_count() -> int
@abstract func get_damage_die_sides() -> int
@abstract func get_damage_bonus() -> int


## Damage taken off each hit. Only skills and items give it, so enemies have none so far.
func get_damage_reduction() -> int:
	return 0


## A crit against a crit-resistant combatant hits but rolls the damage dice only once.
func is_crit_resistant() -> bool:
	return false


func is_alive() -> bool:
	return hit_points > 0


func take_damage(amount: int) -> void:
	assert(amount >= 0, "Damage must not be negative")
	hit_points = maxi(hit_points - amount, 0)


## Returns the hit points actually restored, which is less than amount near full health.
func heal(amount: int) -> int:
	assert(amount >= 0, "Healing must not be negative")
	var before: int = hit_points
	hit_points = mini(hit_points + amount, max_hit_points)
	return hit_points - before
