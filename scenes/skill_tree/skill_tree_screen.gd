class_name SkillTreeScreen
extends Control
## Skill tree screen after the post-fight screen: the tree with the trunk and the specializations
## branching from it, the selected node's details beside it and a button to spend the level-up's
## point on it.

var _progress: SkillTreeProgress
var _selected: SkillNodeData = null

@onready var _continue_button: Button = %ContinueButton
@onready var _character_button: Button = %CharacterButton
@onready var _hint_label: Label = %HintLabel
@onready var _tree_view: SkillTreeView = %TreeView
@onready var _node_name_label: Label = %NodeNameLabel
@onready var _node_details_label: Label = %NodeDetailsLabel
@onready var _learn_button: Button = %LearnButton
@onready var _character_sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	_progress = RunState.skill_tree
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
	_continue_button.pressed.connect(_on_continue_pressed)
	_learn_button.pressed.connect(learn_selected)
	_tree_view.build(_progress)
	_tree_view.node_pressed.connect(select_node)
	select_node(_first_learnable_node())
	_refresh()


func node_button(node_id: StringName) -> Button:
	return _tree_view.node_button(node_id)


func selected_node() -> SkillNodeData:
	return _selected


func select_node(node: SkillNodeData) -> void:
	_selected = node
	_tree_view.select(node)
	_show_details()


## Spends a point on the selected node, when it can be learned.
func learn_selected() -> void:
	if _selected == null or not _progress.can_learn(_selected, RunState.player):
		return
	_progress.learn(_selected, RunState.player)
	_refresh()


func _first_learnable_node() -> SkillNodeData:
	for branch: SkillBranchData in _progress.branches():
		for node: SkillNodeData in branch.nodes:
			if _progress.can_learn(node, RunState.player):
				return node
	return null


func _refresh() -> void:
	_tree_view.refresh(RunState.player)
	_hint_label.text = _hint_text()
	_show_details()
	if _progress.points_available(RunState.player) == 0:
		_continue_button.grab_focus()


func _hint_text() -> String:
	var points: int = _progress.points_available(RunState.player)
	var text: String = "Level %d   ·   Skill points: %d" % [RunState.player.level, points]
	if _progress.specialization != null:
		return text + "   ·   Specialization: %s" % _progress.specialization.display_name
	var trunk_ranks: int = _progress.branch_ranks(_progress.tree.trunk)
	var needed: int = _progress.tree.specialization_trunk_ranks
	if trunk_ranks < needed:
		return (
			text
			+ (
				"   ·   Specializations open after %s (%d/%d)."
				% [_skill_count_text(needed, _progress.tree.trunk), trunk_ranks, needed]
			)
		)
	return (
		text
		+ (
			"   ·   Choose your specialization: the first skill you learn in a branch closes"
			+ " the other two for this run."
		)
	)


func _show_details() -> void:
	if _selected == null:
		_node_name_label.text = ""
		_node_details_label.text = "No skill can be learned right now."
		_learn_button.disabled = true
		return
	var shown: SkillData = _progress.next_rank_skill(_selected)
	if shown == null:
		shown = _progress.current_rank_skill(_selected)
	_node_name_label.text = shown.display_name
	_node_details_label.text = "\n".join(_detail_lines(shown))
	_learn_button.disabled = not _progress.can_learn(_selected, RunState.player)
	_learn_button.text = "Maxed" if _progress.is_maxed(_selected) else "Learn"


func _detail_lines(shown: SkillData) -> Array[String]:
	var lines: Array[String] = [
		(
			"Rank %d/%d   ·   %s"
			% [_progress.rank_of(_selected), _selected.ranks.size(), _describe_activation(shown)]
		),
		shown.description,
	]
	var current: SkillData = _progress.current_rank_skill(_selected)
	if current != null and current != shown:
		lines.append("Now: %s" % current.description)
	if not _progress.is_maxed(_selected):
		for change: StatSheet.Change in StatSheet.preview_skill(RunState.player, shown, current):
			lines.append("%s %s → %s" % [change.label, change.before, change.after])
		# The notes need the max HP after learning.
		var after: Character = RunState.player.copy()
		after.learn_skill(shown, current)
		lines.append_array(StatSheet.condition_notes(after.max_hit_points, shown.effects))
	lines.append_array(_blocker_texts())
	return lines


func _describe_activation(skill: SkillData) -> String:
	if skill.activation == SkillData.Activation.PASSIVE:
		return "Passive."
	return "Active, %d Momentum." % skill.momentum_cost


# Why the node cannot be learned yet, in the player's words.
func _blocker_texts() -> Array[String]:
	var texts: Array[String] = []
	var branch: SkillBranchData = _progress.branch_of(_selected)
	if not _progress.is_branch_open(branch):
		if _progress.specialization != null:
			texts.append("Closed: you chose %s." % _progress.specialization.display_name)
		else:
			var needed: int = _progress.tree.specialization_trunk_ranks
			texts.append("Opens after %s." % _skill_count_text(needed, _progress.tree.trunk))
	if RunState.player.level < _selected.min_level:
		texts.append("Needs level %d." % _selected.min_level)
	if _progress.branch_ranks(branch) < _selected.required_branch_ranks:
		texts.append("Opens after %s." % _skill_count_text(_selected.required_branch_ranks, branch))
	if _selected.required_node != &"":
		var required: SkillNodeData = _progress.find_node(branch, _selected.required_node)
		if _progress.rank_of(required) < _selected.required_rank:
			texts.append("Needs %s." % required.ranks[_selected.required_rank - 1].display_name)
	return texts


# "2 Training skills", "1 Training skill".
func _skill_count_text(count: int, branch: SkillBranchData) -> String:
	return "%d %s skill%s" % [count, branch.display_name, "" if count == 1 else "s"]


func _on_continue_pressed() -> void:
	# Disabled first, so a second press cannot advance the room twice.
	_continue_button.disabled = true
	RunState.advance_room()
	get_tree().change_scene_to_file(LevelUp.room_scene_path())
