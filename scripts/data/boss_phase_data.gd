class_name BossPhaseData
extends Resource
## A later phase of a boss. It starts once the boss's hit points drop to the threshold.

## The phase starts when the boss is still alive with at most this many hit points.
@export var hit_points_at_most: int = 0
## Shown in the combat log when the phase starts.
@export var announcement: String = ""
## Replaces the boss's armor class. 0 keeps the armor class of the data.
@export var armor_class: int = 0
@export var momentum_per_round: int = 0
@export var momentum_cap: int = 0
## Replace the intents of the earlier phase, ordered by Momentum cost like EnemyData.intents.
@export var intents: Array[EnemyIntentData] = []
## Join the fight when the phase starts and fall when the boss falls.
@export var summons: Array[EnemyData] = []
