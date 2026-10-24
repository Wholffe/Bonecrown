extends GutTest
## SkillTreeView: the trunk at the bottom, specializations branching upward side by side, rows by
## level, rank and name on each node, colors and the layout following the size.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const VIEW_SIZE: Vector2 = Vector2(900, 600)

var _view: SkillTreeView
var _progress: SkillTreeProgress
var _player: Character


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_player.level_up()
	_progress = SkillTreeProgress.new(WARRIOR.skill_tree)
	_view = SkillTreeView.new()
	_view.size = VIEW_SIZE
	add_child_autofree(_view)
	_view.build(_progress)
	_view.refresh(_player)


func _center_of(node_id: StringName) -> Vector2:
	var button: Button = _view.node_button(node_id)
	return button.position + button.size / 2.0


func _node(node_id: StringName) -> SkillNodeData:
	for branch: SkillBranchData in _progress.branches():
		var node: SkillNodeData = _progress.find_node(branch, node_id)
		if node != null:
			return node
	return null


func test_specializations_grow_above_the_trunk() -> void:
	var lowest_branch_y: float = 0.0
	for branch: SkillBranchData in WARRIOR.skill_tree.specializations:
		for node: SkillNodeData in branch.nodes:
			lowest_branch_y = maxf(lowest_branch_y, _center_of(node.id).y)
	for node: SkillNodeData in WARRIOR.skill_tree.trunk.nodes:
		assert_gt(_center_of(node.id).y, lowest_branch_y, "%s below the branches" % node.id)


func test_nodes_sit_above_the_node_they_build_on() -> void:
	for branch: SkillBranchData in WARRIOR.skill_tree.specializations:
		for node: SkillNodeData in branch.nodes:
			if node.required_node != &"":
				assert_lt(_center_of(node.id).y, _center_of(node.required_node).y, "%s" % node.id)


func test_specializations_stand_side_by_side() -> void:
	assert_lt(_center_of(&"dragon_breath").x, _center_of(&"mighty_blow").x)
	assert_lt(_center_of(&"mighty_blow").x, _center_of(&"shield_stance").x)


func test_equal_levels_share_a_row_across_branches() -> void:
	assert_eq(_center_of(&"fire_heart").y, _center_of(&"shield_bash").y, "level 5")
	assert_eq(_center_of(&"inferno").y, _center_of(&"bastion").y, "level 8")


func test_nodes_show_their_rank_or_the_missing_level_and_their_name() -> void:
	var button: Button = _view.node_button(&"dragon_breath")
	var name_label: Label = button.get_node("NameLabel") as Label

	assert_eq(button.text, "Lv 3")
	assert_eq(name_label.text, "Dragon Breath")
	assert_eq(_view.node_button(&"toughness").text, "0/2")


func test_learned_node_turns_gold() -> void:
	_progress.learn(_node(&"strength_training"), _player)

	_view.refresh(_player)

	var name_label: Label = _view.node_button(&"strength_training").get_node("NameLabel") as Label
	assert_eq(name_label.get_theme_color("font_color"), SkillTreeView.LEARNED_COLOR)
	assert_eq(_view.node_button(&"strength_training").text, "1/2")


func test_chosen_specialization_title_turns_gold() -> void:
	_player.level_up()
	_progress.learn(_node(&"shield_stance"), _player)

	_view.refresh(_player)

	var title: Label = _view.branch_layer(&"bulwark").get_node("Title") as Label
	assert_eq(title.get_theme_color("font_color"), SkillTreeView.LEARNED_COLOR)


func test_layout_follows_the_size() -> void:
	var before: Vector2 = _center_of(&"dragon_breath")

	_view.size = VIEW_SIZE * 2.0

	assert_almost_eq(_center_of(&"dragon_breath").x, before.x * 2.0, 0.5)


func test_pressing_a_node_emits_it() -> void:
	watch_signals(_view)

	_view.node_button(&"focus").pressed.emit()

	assert_signal_emitted_with_parameters(_view, "node_pressed", [_node(&"focus")])
