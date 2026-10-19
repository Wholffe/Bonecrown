class_name ConditionalModifierEffect
extends StatModifierEffect
## Stat modifier that only counts while its condition holds.

# Stored as numbers in .tres files: append new members, never renumber.
# UNSET is the default, so every real value is written to the .tres explicitly.
enum Condition { OWN_HP_AT_MOST_HALF = 0, UNSET = -1 }

@export var condition: Condition = Condition.UNSET
