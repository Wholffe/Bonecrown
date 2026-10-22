class_name Enemy
extends Combatant
## One enemy in a fight. Hit points live here, so the shared EnemyData stays untouched.

var data: EnemyData
## Announced at the start of each round and carried out on the enemy's turn.
var intent: EnemyIntentData
## Room scaling and the elite room add this to the attack bonus of the data.
var _attack_modifier: int = 0


## attack_modifier and hit_point_percent come from room scaling and the elite room.
func _init(enemy_data: EnemyData, attack_modifier: int = 0, hit_point_percent: int = 0) -> void:
	data = enemy_data
	_attack_modifier = attack_modifier
	display_name = enemy_data.display_name
	max_hit_points = roundi(enemy_data.max_hit_points * (100 + hit_point_percent) / 100.0)
	hit_points = max_hit_points
	momentum = enemy_data.starting_momentum


## Creates the enemies of one encounter and numbers duplicates ("Goblin 1", "Goblin 2").
## The modifiers and the name prefix ("Elite Goblin 1") apply to every enemy of the group.
static func create_group(
	enemy_datas: Array[EnemyData],
	attack_modifier: int = 0,
	hit_point_percent: int = 0,
	name_prefix: String = ""
) -> Array[Combatant]:
	# Counted by display name, because that is what the player has to tell apart.
	var counts: Dictionary[String, int] = {}
	for enemy_data: EnemyData in enemy_datas:
		counts[enemy_data.display_name] = counts.get(enemy_data.display_name, 0) + 1
	var numbers: Dictionary[String, int] = {}
	var group: Array[Combatant] = []
	for enemy_data: EnemyData in enemy_datas:
		var base_name: String = enemy_data.display_name
		# new() instead of Enemy.new(): naming its own class_name here leaks the script at exit.
		var enemy: Enemy = new(enemy_data, attack_modifier, hit_point_percent)
		enemy.display_name = name_prefix + base_name
		if counts[base_name] > 1:
			numbers[base_name] = numbers.get(base_name, 0) + 1
			enemy.display_name = "%s %d" % [enemy.display_name, numbers[base_name]]
		group.append(enemy)
	return group


func get_armor_class() -> int:
	return data.armor_class


func get_attack_bonus() -> int:
	return data.attack_bonus + _attack_modifier


func get_crit_threshold() -> int:
	return AttackRoll.DIE_SIDES


func get_damage_die_count() -> int:
	return data.damage_die_count


func get_damage_die_sides() -> int:
	return data.damage_die_sides


func get_damage_bonus() -> int:
	return data.damage_bonus


func is_crit_resistant() -> bool:
	return data.crit_resistant


## The most expensive intent the enemy can pay for with its current Momentum.
func choose_intent() -> void:
	intent = null
	for candidate: EnemyIntentData in data.intents:
		if candidate.momentum_cost <= momentum:
			intent = candidate
