class_name AttackResolver
extends RefCounted
## Rolls attacks and damage with the injected dice.

const DOUBLED_DICE_FACTOR: int = 2

var _dice: DiceRoller


func _init(dice: DiceRoller) -> void:
	_dice = dice


func roll_attack(attack_bonus: int, target_armor_class: int, crit_threshold: int) -> AttackRoll:
	var natural_roll: int = _dice.roll(AttackRoll.DIE_SIDES)
	return AttackRoll.new(natural_roll, attack_bonus, target_armor_class, crit_threshold)


## Doubling rolls twice as many dice (5e style); the flat bonus is never doubled.
## Callers pass double_dice = false for crits against crit-resistant targets.
func roll_damage(
	die_count: int, die_sides: int, damage_bonus: int, double_dice: bool
) -> DamageRoll:
	var count: int = die_count * DOUBLED_DICE_FACTOR if double_dice else die_count
	return DamageRoll.new(_dice.roll_many(count, die_sides), damage_bonus)
