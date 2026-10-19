class_name StatModifierEffect
extends EffectData
## Flat bonus on one combat stat while the skill is owned. Only counts on passive skills.

# Stored as numbers in .tres files: append new members, never renumber.
# UNSET is the default, so every real value is written to the .tres explicitly.
enum Stat { ATTACK = 0, MELEE_DAMAGE = 1, ARMOR_CLASS = 2, UNSET = -1 }

@export var stat: Stat = Stat.UNSET
@export var amount: int = 0
