class_name EnemyIntentData
extends Resource
## One thing an enemy can do on its turn. It is announced at the start of the round.

@export var id: StringName
@export var display_name: String
## Momentum the enemy needs and spends. The enemy picks the most expensive intent it can pay.
@export var momentum_cost: int = 0
@export var attack_count: int = 0
## Added to the enemy's damage dice on every attack of this intent.
@export var extra_damage_dice: int = 0
## Momentum the player loses on every hit of this intent.
@export var momentum_drain: int = 0
## Momentum every other living enemy gains after this intent.
@export var momentum_to_allies: int = 0
