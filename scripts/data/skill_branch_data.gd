class_name SkillBranchData
extends Resource
## A group of skill tree nodes: the trunk shared by every build, or one specialization.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var nodes: Array[SkillNodeData] = []
