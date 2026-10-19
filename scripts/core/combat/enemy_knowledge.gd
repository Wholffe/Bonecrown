class_name EnemyKnowledge
extends RefCounted
## What the player has learned about each enemy type during a run, from the attack rolls shown.

const UNKNOWN: int = -1

# Only ints keyed by EnemyData.id, so a later save system can store them as they are.
var _lowest_armor_classes: Dictionary[StringName, int] = {}
var _highest_armor_classes: Dictionary[StringName, int] = {}
var _attack_bonuses: Dictionary[StringName, int] = {}


## Narrows the armor class of the enemy type from an attack roll of the player against it.
func record_player_attack(enemy_id: StringName, attack: AttackRoll) -> void:
	# A crit hits and a natural 1 misses whatever the armor class is, so neither proves anything.
	if attack.is_crit or attack.is_natural_one:
		return
	if attack.is_hit:
		_lower_highest_armor_class(enemy_id, attack.total)
		if attack.is_narrow_hit:
			_raise_lowest_armor_class(enemy_id, attack.total - AttackRoll.NARROW_HIT_MARGIN)
	else:
		_raise_lowest_armor_class(enemy_id, attack.total + 1)


## Learns the attack bonus of the enemy type from the latest attack roll it made.
func record_enemy_attack(enemy_id: StringName, attack: AttackRoll) -> void:
	# Every roll counts, natural 1 and 20 included, because the shown roll includes the bonus.
	_attack_bonuses[enemy_id] = attack.attack_bonus


## Lowest armor class the rolls so far allow, or UNKNOWN.
func lowest_armor_class(enemy_id: StringName) -> int:
	return _lowest_armor_classes.get(enemy_id, UNKNOWN)


## Highest armor class the rolls so far allow, or UNKNOWN.
func highest_armor_class(enemy_id: StringName) -> int:
	return _highest_armor_classes.get(enemy_id, UNKNOWN)


func is_armor_class_known(enemy_id: StringName) -> bool:
	return (
		enemy_id in _lowest_armor_classes
		and enemy_id in _highest_armor_classes
		and _lowest_armor_classes[enemy_id] == _highest_armor_classes[enemy_id]
	)


func is_attack_bonus_known(enemy_id: StringName) -> bool:
	return enemy_id in _attack_bonuses


## Attack bonus of the enemy type, or UNKNOWN.
func attack_bonus(enemy_id: StringName) -> int:
	return _attack_bonuses.get(enemy_id, UNKNOWN)


func _raise_lowest_armor_class(enemy_id: StringName, armor_class: int) -> void:
	var lowest: int = _lowest_armor_classes.get(enemy_id, armor_class)
	_lowest_armor_classes[enemy_id] = maxi(lowest, armor_class)


func _lower_highest_armor_class(enemy_id: StringName, armor_class: int) -> void:
	var highest: int = _highest_armor_classes.get(enemy_id, armor_class)
	_highest_armor_classes[enemy_id] = mini(highest, armor_class)
