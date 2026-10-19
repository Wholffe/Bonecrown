class_name Character
extends Combatant
## The player character: class data plus run progress (level, equipment, current hit points).

const STARTING_LEVEL: int = 1

var class_data: ClassData
var attributes: Attributes
var level: int = STARTING_LEVEL
var weapon: WeaponData
var armor: ArmorData
var _proficiency_bonus: int


func _init(data: ClassData, proficiency_bonus: int) -> void:
	class_data = data
	display_name = data.display_name
	attributes = Attributes.new(data.strength, data.dexterity, data.constitution, data.luck)
	weapon = data.starting_weapon
	armor = data.starting_armor
	_proficiency_bonus = proficiency_bonus
	max_hit_points = data.base_hit_points + attributes.bonus_of(Attributes.Kind.CONSTITUTION)
	hit_points = max_hit_points


func get_armor_class() -> int:
	return CombatFormulas.armor_class(
		armor.armor_base, attributes.bonus_of(Attributes.Kind.DEXTERITY)
	)


func get_attack_bonus() -> int:
	return CombatFormulas.melee_attack_bonus(
		attributes.bonus_of(Attributes.Kind.STRENGTH), _proficiency_bonus
	)


func get_crit_threshold() -> int:
	return CombatFormulas.crit_threshold(attributes.bonus_of(Attributes.Kind.LUCK))


func get_damage_die_count() -> int:
	return weapon.damage_die_count


func get_damage_die_sides() -> int:
	return weapon.damage_die_sides


func get_damage_bonus() -> int:
	return attributes.bonus_of(Attributes.Kind.STRENGTH)
