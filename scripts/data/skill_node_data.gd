class_name SkillNodeData
extends Resource
## One node of a skill tree: its ranks, the node it builds on and the level it opens at.

@export var id: StringName
## Rank n learns ranks[n - 1], which replaces the skill of the rank before it.
@export var ranks: Array[SkillData] = []
## Id of a node in the same branch that needs required_rank first. Empty for the first node.
@export var required_node: StringName
@export var required_rank: int = 0
## Lowest character level at which the node can be learned.
@export var min_level: int = 0
## Ranks learned anywhere in the node's own branch before it opens, for the later tiers of a branch.
@export var required_branch_ranks: int = 0
