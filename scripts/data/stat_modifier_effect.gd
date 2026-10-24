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
	MOMENTUM_CAP = 8,
	MOMENTUM_AT_FIGHT_START = 9,
	MOMENTUM_PER_KILL = 10,
	MOMENTUM_PER_FENDED_ATTACK = 11,
	ATTACK_MOMENTUM_COST = 12,
	BLOCK_MOMENTUM_COST = 13,
	UNSET = -1,
}

@export var stat: Stat = Stat.UNSET
@export var amount: int = 0
