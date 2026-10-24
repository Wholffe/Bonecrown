class_name MomentumGainEffect
extends EffectData
## The user gains Momentum, optionally paid for with hit points.

@export var amount: int = 0
## The skill cannot be used while the user has this many hit points or fewer.
@export var hit_point_cost: int = 0
