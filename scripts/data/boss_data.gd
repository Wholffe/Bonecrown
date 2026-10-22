class_name BossData
extends EnemyData
## An enemy with phases. The values of EnemyData are its first phase.

## Ordered by threshold, highest first.
@export var phases: Array[BossPhaseData] = []
