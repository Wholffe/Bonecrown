extends GutTest
## SkillTreeProgress: points per level-up, ranks, requirements, level gates and the specialization
## that closes the other branches. Uses a small tree built here, so the rules read on their own.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const TOUGHNESS: SkillData = preload("res://scripts/data/skills/toughness.tres")
const TOUGHNESS_2: SkillData = preload("res://scripts/data/skills/toughness_2.tres")
const DRAGON_BREATH: SkillData = preload("res://scripts/data/skills/dragon_breath.tres")
const DRACONIC_SCALES: SkillData = preload("res://scripts/data/skills/draconic_scales.tres")
const MIGHTY_BLOW: SkillData = preload("res://scripts/data/skills/mighty_blow.tres")
const SPECIALIZATION_LEVEL: int = 3

var _player: Character
var _progress: SkillTreeProgress
var _toughness: SkillNodeData
var _breath: SkillNodeData
var _scales: SkillNodeData
var _blow: SkillNodeData
var _trunk: SkillBranchData
var _fire: SkillBranchData
var _rage: SkillBranchData


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_toughness = _node(&"toughness", [TOUGHNESS, TOUGHNESS_2], 2)
	_breath = _node(&"breath", [DRAGON_BREATH], SPECIALIZATION_LEVEL)
	_scales = _node(&"scales", [DRACONIC_SCALES], SPECIALIZATION_LEVEL, &"breath")
	_blow = _node(&"blow", [MIGHTY_BLOW], SPECIALIZATION_LEVEL)
	_trunk = _branch(&"trunk", [_toughness])
	_fire = _branch(&"fire", [_breath, _scales])
	_rage = _branch(&"rage", [_blow])
	var tree: SkillTreeData = SkillTreeData.new()
	tree.trunk = _trunk
	tree.specializations = [_fire, _rage]
	tree.specialization_level = SPECIALIZATION_LEVEL
	_progress = SkillTreeProgress.new(tree)


func _node(
	id: StringName, ranks: Array[SkillData], min_level: int, required_node: StringName = &""
) -> SkillNodeData:
	var node: SkillNodeData = SkillNodeData.new()
	node.id = id
	node.ranks = ranks
	node.min_level = min_level
	node.required_node = required_node
	node.required_rank = 0 if required_node == &"" else 1
	return node


func _branch(id: StringName, nodes: Array[SkillNodeData]) -> SkillBranchData:
	var branch: SkillBranchData = SkillBranchData.new()
	branch.id = id
	branch.nodes = nodes
	return branch


func _level_up_to(level: int) -> void:
	while _player.level < level:
		_player.level_up()


func test_every_level_up_gives_one_point() -> void:
	assert_eq(_progress.points_available(_player), 0, "level 1")

	_level_up_to(3)

	assert_eq(_progress.points_available(_player), 2, "level 3")


func test_learning_spends_a_point_and_learns_the_first_rank() -> void:
	_level_up_to(2)

	_progress.learn(_toughness, _player)

	assert_eq(_progress.rank_of(_toughness), 1)
	assert_eq(_progress.points_available(_player), 0)
	assert_has(_player.skills, TOUGHNESS)


func test_next_rank_replaces_the_rank_before_it() -> void:
	_level_up_to(3)
	_progress.learn(_toughness, _player)

	_progress.learn(_toughness, _player)

	assert_has(_player.skills, TOUGHNESS_2)
	assert_does_not_have(_player.skills, TOUGHNESS)
	assert_eq(_player.attribute_value(Attributes.Kind.CONSTITUTION), 18, "14 + 4, not 14 + 6")


func test_maxed_node_cannot_be_learned_again() -> void:
	_level_up_to(4)
	_progress.learn(_toughness, _player)
	_progress.learn(_toughness, _player)

	assert_true(_progress.is_maxed(_toughness))
	assert_null(_progress.next_rank_skill(_toughness))
	assert_eq(_progress.current_rank_skill(_toughness), TOUGHNESS_2)
	assert_false(_progress.can_learn(_toughness, _player))


func test_no_point_left_means_nothing_can_be_learned() -> void:
	_level_up_to(2)
	_progress.learn(_toughness, _player)

	assert_false(_progress.can_learn(_toughness, _player))
	assert_false(_progress.has_learnable_node(_player))


func test_learning_without_a_point_changes_nothing() -> void:
	_progress.learn(_toughness, _player)

	assert_push_error_count(1)
	assert_eq(_progress.rank_of(_toughness), 0)
	assert_does_not_have(_player.skills, TOUGHNESS)


func test_specializations_stay_closed_below_their_level() -> void:
	_level_up_to(2)

	assert_true(_progress.is_branch_open(_trunk, _player.level))
	assert_false(_progress.is_branch_open(_fire, _player.level))
	assert_false(_progress.is_unlocked(_breath, _player.level))


func test_specializations_open_at_their_level() -> void:
	_level_up_to(SPECIALIZATION_LEVEL)

	assert_true(_progress.can_learn(_breath, _player))
	assert_true(_progress.can_learn(_blow, _player))


func test_first_specialization_node_closes_the_other_branches() -> void:
	_level_up_to(4)

	_progress.learn(_breath, _player)

	assert_eq(_progress.specialization, _fire)
	assert_true(_progress.is_branch_open(_fire, _player.level))
	assert_false(_progress.is_branch_open(_rage, _player.level))
	assert_false(_progress.can_learn(_blow, _player), "a point is left, but Rage is closed")
	assert_true(_progress.can_learn(_toughness, _player), "the trunk stays open")


func test_trunk_nodes_choose_no_specialization() -> void:
	_level_up_to(SPECIALIZATION_LEVEL)

	_progress.learn(_toughness, _player)

	assert_null(_progress.specialization)
	assert_true(_progress.is_branch_open(_rage, _player.level))


func test_node_needs_its_required_node_first() -> void:
	_level_up_to(4)
	assert_false(_progress.is_requirement_met(_scales))
	assert_false(_progress.can_learn(_scales, _player))

	_progress.learn(_breath, _player)

	assert_true(_progress.can_learn(_scales, _player))


func test_node_below_its_level_cannot_be_learned() -> void:
	_scales.min_level = 5
	_level_up_to(4)
	_progress.learn(_breath, _player)

	assert_false(_progress.can_learn(_scales, _player))


func test_branch_of_and_find_node_look_up_the_tree() -> void:
	assert_eq(_progress.branch_of(_scales), _fire)
	assert_eq(_progress.find_node(_fire, &"breath"), _breath)
	assert_eq(_progress.branches(), [_trunk, _fire, _rage] as Array[SkillBranchData])
