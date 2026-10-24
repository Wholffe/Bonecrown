class_name SkillTreeData
extends Resource
## The skill tree of a class: a trunk open to every build and the specializations, of which a run
## keeps the first one it learns a node in.

@export var trunk: SkillBranchData
@export var specializations: Array[SkillBranchData] = []
## Training ranks the player learns before a specialization can be chosen.
@export var specialization_trunk_ranks: int = 0
