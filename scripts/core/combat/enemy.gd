class_name Enemy
extends Combatant
## One enemy in a fight. Hit points live here, so the shared EnemyData stays untouched.

## The phase index while the values of the data itself apply.
const FIRST_PHASE: int = -1

var data: EnemyData
## Announced at the start of each round and carried out on the enemy's turn.
var intent: EnemyIntentData
## The boss that summoned this enemy. A summon falls with its summoner.
var summoner: Enemy
## Room scaling and the elite room add this to the attack bonus of the data.
var _attack_modifier: int = 0
## Index into the phases of BossData, or FIRST_PHASE.
var _phase_index: int = FIRST_PHASE


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
	var phase: BossPhaseData = current_phase()
	if phase != null and phase.armor_class > 0:
		return phase.armor_class
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


## Null while the values of the data itself apply.
func current_phase() -> BossPhaseData:
	if _phase_index == FIRST_PHASE:
		return null
	return (data as BossData).phases[_phase_index]


func momentum_per_round() -> int:
	var phase: BossPhaseData = current_phase()
	return phase.momentum_per_round if phase != null else data.momentum_per_round


func momentum_cap() -> int:
	var phase: BossPhaseData = current_phase()
	return phase.momentum_cap if phase != null else data.momentum_cap


func intents() -> Array[EnemyIntentData]:
	var phase: BossPhaseData = current_phase()
	return phase.intents if phase != null else data.intents


## Starts the next phase once the hit points have dropped to its threshold and returns it, else
## null. One hit can reach several thresholds, so call it until it returns null.
func enter_next_phase() -> BossPhaseData:
	var boss_data: BossData = data as BossData
	var next_index: int = _phase_index + 1
	if boss_data == null or not is_alive() or next_index >= boss_data.phases.size():
		return null
	var phase: BossPhaseData = boss_data.phases[next_index]
	if hit_points > phase.hit_points_at_most:
		return null
	_phase_index = next_index
	momentum = mini(momentum, phase.momentum_cap)
	return phase


## The most expensive intent the enemy can pay for with its current Momentum.
func choose_intent() -> void:
	intent = null
	for candidate: EnemyIntentData in intents():
		if candidate.momentum_cost <= momentum:
			intent = candidate
