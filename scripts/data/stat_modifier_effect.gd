class_name StatModifierEffect
extends EffectData
## Flat bonus on one combat stat while the skill is owned. Only counts on passive skills.

# Stored as numbers in .tres files: append new members, never renumber.
enum Stat { ATTACK = 0, MELEE_DAMAGE = 1, ARMOR_CLASS = 2 }

@export var stat: Stat = Stat.ATTACK
@export var amount: int = 0
