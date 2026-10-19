class_name StatModifierEffect
extends EffectData
## Flat bonus on a combat stat or attribute while a passive skill is owned or an item is worn.

# Stored as numbers in .tres files: append new members, never renumber.
# UNSET is the default, so every real value is written to the .tres explicitly.
enum Stat {
	ATTACK = 0,
	MELEE_DAMAGE = 1,
	ARMOR_CLASS = 2,
	STRENGTH = 3,
	DEXTERITY = 4,
	CONSTITUTION = 5,
	LUCK = 6,
	DAMAGE_REDUCTION = 7,
	UNSET = -1,
}

@export var stat: Stat = Stat.UNSET
@export var amount: int = 0
