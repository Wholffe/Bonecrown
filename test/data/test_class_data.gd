extends GutTest
## Content rules of the class skill trees: branches, nodes, ranks, requirements and level gates.

const DATA_ROOT: String = "res://scripts/data"
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const WARRIOR_TREE: SkillTreeData = preload("res://scripts/data/skill_trees/warrior.tres")
## Skills with a drawback or a condition open from this level on (DECISIONS 2026-10-20).
const DRAWBACK_MIN_LEVEL: int = 4
## Focus opens at this level (DECISIONS 2026-10-20).
const FOCUS_MIN_LEVEL: int = 3

var _classes: Array[ClassData] = []


func before_all() -> void:
	for path: String in _find_resource_paths(DATA_ROOT):
		var class_data: ClassData = load(path) as ClassData
		if class_data != null:
			_classes.append(class_data)


func _find_resource_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tres"):
			paths.append(directory.path_join(file_name))
	for subdirectory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_find_resource_paths(directory.path_join(subdirectory)))
	return paths


func _branches(tree: SkillTreeData) -> Array[SkillBranchData]:
	var branches: Array[SkillBranchData] = [tree.trunk]
	branches.append_array(tree.specializations)
	return branches


func _rank_count(branch: SkillBranchData) -> int:
	var count: int = 0
	for node: SkillNodeData in branch.nodes:
		count += node.ranks.size()
	return count


func _find_node(branch: SkillBranchData, node_id: StringName) -> SkillNodeData:
	for node: SkillNodeData in branch.nodes:
		if node.id == node_id:
			return node
	return null


func _has_drawback_or_condition(skill: SkillData) -> bool:
	for effect: EffectData in skill.effects:
		if effect is ConditionalModifierEffect:
			return true
		var modifier: StatModifierEffect = effect as StatModifierEffect
		if modifier != null and modifier.amount < 0:
			return true
	return false


func test_classes_exist() -> void:
	assert_gt(_classes.size(), 0, "No classes found under %s" % DATA_ROOT)


func test_classes_have_a_tree_with_a_trunk_and_specializations() -> void:
	for class_data: ClassData in _classes:
		var tree: SkillTreeData = class_data.skill_tree
		assert_not_null(tree, "%s has no skill tree" % class_data.id)
		assert_not_null(tree.trunk, "%s has no trunk" % class_data.id)
		assert_gt(tree.specializations.size(), 1, "%s specializations" % class_data.id)
		assert_does_not_have(tree.specializations, null, "%s specializations" % class_data.id)


func test_branches_have_texts_and_nodes_without_empty_slots() -> void:
	for class_data: ClassData in _classes:
		for branch: SkillBranchData in _branches(class_data.skill_tree):
			assert_ne(branch.id, &"", "%s: branch without id" % class_data.id)
			assert_ne(branch.display_name, "", "%s: %s display name" % [class_data.id, branch.id])
			assert_ne(branch.description, "", "%s: %s description" % [class_data.id, branch.id])
			assert_gt(branch.nodes.size(), 0, "%s: %s has no nodes" % [class_data.id, branch.id])
			assert_does_not_have(branch.nodes, null, "%s: %s nodes" % [class_data.id, branch.id])


func test_nodes_have_ranks_with_their_own_names() -> void:
	for class_data: ClassData in _classes:
		for branch: SkillBranchData in _branches(class_data.skill_tree):
			for node: SkillNodeData in branch.nodes:
				assert_gt(node.ranks.size(), 0, "%s has no ranks" % node.id)
				assert_does_not_have(node.ranks, null, "%s ranks" % node.id)
				var names: Array[String] = []
				for skill: SkillData in node.ranks:
					assert_does_not_have(names, skill.display_name, "%s rank names" % node.id)
					names.append(skill.display_name)


func test_node_ids_and_skills_are_unique_and_no_starting_skill() -> void:
	for class_data: ClassData in _classes:
		var node_ids: Array[StringName] = []
		var skills: Array[SkillData] = class_data.starting_skills.duplicate()
		for branch: SkillBranchData in _branches(class_data.skill_tree):
			for node: SkillNodeData in branch.nodes:
				assert_does_not_have(node_ids, node.id, "%s: duplicate node" % class_data.id)
				node_ids.append(node.id)
				for skill: SkillData in node.ranks:
					assert_does_not_have(skills, skill, "%s: %s twice" % [class_data.id, skill.id])
					skills.append(skill)


# Listed before the node, so a column reads from top to bottom.
func test_requirements_name_an_earlier_node_of_the_same_branch() -> void:
	for class_data: ClassData in _classes:
		for branch: SkillBranchData in _branches(class_data.skill_tree):
			for index: int in branch.nodes.size():
				var node: SkillNodeData = branch.nodes[index]
				if node.required_node == &"":
					assert_eq(node.required_rank, 0, "%s required rank" % node.id)
					continue
				var required: SkillNodeData = _find_node(branch, node.required_node)
				assert_not_null(required, "%s needs a node outside %s" % [node.id, branch.id])
				if required == null:
					continue
				assert_lt(branch.nodes.find(required), index, "%s order" % node.id)
				assert_between(node.required_rank, 1, required.ranks.size(), "%s rank" % node.id)
				assert_lte(required.min_level, node.min_level, "%s level" % node.id)


func test_trunk_has_a_node_for_the_first_level_up() -> void:
	for class_data: ClassData in _classes:
		var has_first_node: bool = false
		for node: SkillNodeData in class_data.skill_tree.trunk.nodes:
			if (
				node.required_node == &""
				and node.required_branch_ranks == 0
				and node.min_level <= Character.STARTING_LEVEL + 1
			):
				has_first_node = true
		assert_true(has_first_node, "%s: no trunk node at level 2" % class_data.id)


# Every tier needs fewer ranks than the tiers below it can hold.
func test_trunk_tiers_open_with_the_ranks_of_the_tiers_below() -> void:
	for class_data: ClassData in _classes:
		var trunk: SkillBranchData = class_data.skill_tree.trunk
		for node: SkillNodeData in trunk.nodes:
			var ranks_below: int = 0
			for other: SkillNodeData in trunk.nodes:
				if other.required_branch_ranks < node.required_branch_ranks:
					ranks_below += other.ranks.size()
			assert_gte(ranks_below, node.required_branch_ranks, "%s tier" % node.id)


# The Training ranks come one per level-up, so no specialization node opens before they can.
func test_specializations_need_training_ranks_and_have_an_entry_node() -> void:
	for class_data: ClassData in _classes:
		var tree: SkillTreeData = class_data.skill_tree
		var first_level: int = Character.STARTING_LEVEL + tree.specialization_trunk_ranks + 1
		assert_gt(tree.specialization_trunk_ranks, 0, "%s" % class_data.id)
		assert_gte(_rank_count(tree.trunk), tree.specialization_trunk_ranks, "%s" % class_data.id)
		for branch: SkillBranchData in tree.specializations:
			var entry_count: int = 0
			for node: SkillNodeData in branch.nodes:
				assert_gte(node.min_level, first_level, "%s level" % node.id)
				if node.required_node == &"":
					entry_count += 1
			assert_gt(entry_count, 0, "%s has no entry node" % branch.id)


# A level-up follows every fight room, so a build must never run out of nodes to spend points on.
func test_every_specialization_with_the_trunk_takes_every_point_of_a_run() -> void:
	var points_per_run: int = GAME_RULES.room_count - 1
	for class_data: ClassData in _classes:
		var tree: SkillTreeData = class_data.skill_tree
		for branch: SkillBranchData in tree.specializations:
			assert_gte(
				_rank_count(tree.trunk) + _rank_count(branch),
				points_per_run,
				"%s: %s" % [class_data.id, branch.id]
			)


func test_skills_with_a_drawback_or_condition_open_at_level_4() -> void:
	for class_data: ClassData in _classes:
		for branch: SkillBranchData in _branches(class_data.skill_tree):
			for node: SkillNodeData in branch.nodes:
				for skill: SkillData in node.ranks:
					if _has_drawback_or_condition(skill):
						assert_gte(node.min_level, DRAWBACK_MIN_LEVEL, "%s" % skill.id)


func test_warrior_focus_opens_at_level_3() -> void:
	assert_eq(_find_node(WARRIOR_TREE.trunk, &"focus").min_level, FOCUS_MIN_LEVEL)
