class_name Enemy
extends Combatant
## One enemy in a fight. Hit points live here, so the shared EnemyData stays untouched.

var data: EnemyData


func _init(enemy_data: EnemyData) -> void:
	data = enemy_data
	display_name = enemy_data.display_name
	max_hit_points = enemy_data.max_hit_points
	hit_points = max_hit_points


func get_armor_class() -> int:
	return data.armor_class


func get_attack_bonus() -> int:
	return data.attack_bonus


func get_crit_threshold() -> int:
	return AttackRoll.DIE_SIDES


func get_damage_die_count() -> int:
	return data.damage_die_count


func get_damage_die_sides() -> int:
	return data.damage_die_sides


func get_damage_bonus() -> int:
	return data.damage_bonus
