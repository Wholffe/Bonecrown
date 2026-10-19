class_name CombatFormulas
extends RefCounted
## Derived combat values: attack bonus, armor class and crit threshold.

const EXTENDED_CRIT_LUCK_BONUS: int = 2
const EXTENDED_CRIT_THRESHOLD: int = 19


static func melee_attack_bonus(strength_bonus: int, proficiency_bonus: int) -> int:
	return strength_bonus + proficiency_bonus


static func armor_class(armor_base: int, dexterity_bonus: int) -> int:
	return armor_base + dexterity_bonus


## Lowest natural d20 roll that counts as a crit.
static func crit_threshold(luck_bonus: int) -> int:
	if luck_bonus >= EXTENDED_CRIT_LUCK_BONUS:
		return EXTENDED_CRIT_THRESHOLD
	return AttackRoll.DIE_SIDES
