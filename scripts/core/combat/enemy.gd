class_name Enemy
extends Combatant
## One enemy in a fight. Hit points live here, so the shared EnemyData stays untouched.

var data: EnemyData


func _init(enemy_data: EnemyData) -> void:
	data = enemy_data
	display_name = enemy_data.display_name
	max_hit_points = enemy_data.max_hit_points
	hit_points = max_hit_points


## Creates the enemies of one encounter and numbers duplicates ("Goblin 1", "Goblin 2").
static func create_group(enemy_datas: Array[EnemyData]) -> Array[Combatant]:
	var counts: Dictionary[StringName, int] = {}
	for enemy_data: EnemyData in enemy_datas:
		counts[enemy_data.id] = counts.get(enemy_data.id, 0) + 1
	var numbers: Dictionary[StringName, int] = {}
	var group: Array[Combatant] = []
	for enemy_data: EnemyData in enemy_datas:
		# new() instead of Enemy.new(): naming its own class_name here leaks the script at exit.
		var enemy: Enemy = new(enemy_data)
		if counts[enemy_data.id] > 1:
			numbers[enemy_data.id] = numbers.get(enemy_data.id, 0) + 1
			enemy.display_name = "%s %d" % [enemy_data.display_name, numbers[enemy_data.id]]
		group.append(enemy)
	return group


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
