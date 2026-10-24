class_name SkillTreeData
extends Resource
## The skill tree of a class: a trunk open to every build and the specializations, of which a run
## keeps the first one it learns a node in.

@export var trunk: SkillBranchData
@export var specializations: Array[SkillBranchData] = []
## Lowest character level at which a specialization can be chosen.
@export var specialization_level: int = 0
