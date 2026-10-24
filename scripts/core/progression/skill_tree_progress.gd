class_name SkillTreeProgress
extends RefCounted
## The player's progress in the skill tree of their class: the learned ranks and the chosen
## specialization. Every level-up gives one point. The first node learned in a specialization
## chooses it, and the other specializations close for the run.

var tree: SkillTreeData
## Null until the first node of a specialization is learned.
var specialization: SkillBranchData = null
var _ranks: Dictionary[StringName, int] = {}
var _spent_points: int = 0


func _init(skill_tree: SkillTreeData) -> void:
	tree = skill_tree


func rank_of(node: SkillNodeData) -> int:
	return _ranks.get(node.id, 0)


func is_maxed(node: SkillNodeData) -> bool:
	return rank_of(node) >= node.ranks.size()


## The skill the next rank learns, or null once the node is maxed.
func next_rank_skill(node: SkillNodeData) -> SkillData:
	return null if is_maxed(node) else node.ranks[rank_of(node)]


## The skill of the current rank, or null before the first rank.
func current_rank_skill(node: SkillNodeData) -> SkillData:
	var rank: int = rank_of(node)
	return node.ranks[rank - 1] if rank > 0 else null


## One point per level-up that is not spent yet.
func points_available(character: Character) -> int:
	return character.level - Character.STARTING_LEVEL - _spent_points


## The trunk is always open. Specializations open at the specialization level, and once one is
## chosen, the others close.
func is_branch_open(branch: SkillBranchData, level: int) -> bool:
	if branch == tree.trunk:
		return true
	if specialization != null:
		return branch == specialization
	return level >= tree.specialization_level


func is_requirement_met(node: SkillNodeData) -> bool:
	if node.required_node == &"":
		return true
	return _ranks.get(node.required_node, 0) >= node.required_rank


## Whether the node could be learned now, ignoring the points left.
func is_unlocked(node: SkillNodeData, level: int) -> bool:
	return (
		not is_maxed(node)
		and level >= node.min_level
		and is_branch_open(branch_of(node), level)
		and is_requirement_met(node)
	)


func can_learn(node: SkillNodeData, character: Character) -> bool:
	return points_available(character) > 0 and is_unlocked(node, character.level)


## Whether any node is worth a point now, so the tree screen can be skipped otherwise.
func has_learnable_node(character: Character) -> bool:
	for branch: SkillBranchData in branches():
		for node: SkillNodeData in branch.nodes:
			if can_learn(node, character):
				return true
	return false


## Spends a point on the node's next rank, which replaces the rank before it.
func learn(node: SkillNodeData, character: Character) -> void:
	if not can_learn(node, character):
		push_error("%s cannot be learned now" % node.id)
		return
	character.learn_skill(next_rank_skill(node), current_rank_skill(node))
	_ranks[node.id] = rank_of(node) + 1
	_spent_points += 1
	var branch: SkillBranchData = branch_of(node)
	if specialization == null and branch != tree.trunk:
		specialization = branch


## The trunk first, then the specializations.
func branches() -> Array[SkillBranchData]:
	var all: Array[SkillBranchData] = [tree.trunk]
	all.append_array(tree.specializations)
	return all


func branch_of(node: SkillNodeData) -> SkillBranchData:
	for branch: SkillBranchData in branches():
		if node in branch.nodes:
			return branch
	push_error("%s is not part of the skill tree" % node.id)
	return null


## The node with this id in the node's branch, for showing a requirement.
func find_node(branch: SkillBranchData, node_id: StringName) -> SkillNodeData:
	for node: SkillNodeData in branch.nodes:
		if node.id == node_id:
			return node
	return null
