class_name AttackEffect
extends EffectData
## An attack on the selected target with its own modifiers, used by active skills.

## Added to the attack roll, negative for a risky swing.
@export var attack_bonus: int = 0
## Added to the weapon's damage dice.
@export var extra_damage_dice: int = 0
## On a hit, every other living enemy takes this damage, rolled once for all of them.
@export var splash_die_count: int = 0
@export var splash_die_sides: int = 0
## On a hit, the target loses this much Momentum and re-chooses its intent if it cannot pay it.
@export var momentum_drain: int = 0
