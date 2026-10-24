class_name SkillTreeScreen
extends Control
## Skill tree screen after the post-fight screen: the trunk and the specializations side by side,
## the selected node's details below and a button to spend the level-up's point on it.

const COLUMN_WIDTH: float = 290.0
const BRANCH_NAME_FONT_SIZE: int = 22
const BRANCH_DESCRIPTION_FONT_SIZE: int = 14
const LEARNED_COLOR: Color = Color(1.0, 0.82, 0.35)
const LOCKED_COLOR: Color = Color(0.5, 0.5, 0.55)
## A closed specialization fades, so the chosen one stands out.
const CLOSED_BRANCH_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.45)

var _progress: SkillTreeProgress
var _selected: SkillNodeData = null
var _node_buttons: Dictionary[SkillNodeData, Button] = {}
var _columns_by_branch: Dictionary[SkillBranchData, VBoxContainer] = {}
var _button_group: ButtonGroup = ButtonGroup.new()

@onready var _continue_button: Button = %ContinueButton
@onready var _character_button: Button = %CharacterButton
@onready var _hint_label: Label = %HintLabel
@onready var _columns: HBoxContainer = %Columns
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
	for branch: SkillBranchData in _progress.branches():
		_columns.add_child(_create_column(branch))
	select_node(_first_learnable_node())
	_refresh()


func node_button(node_id: StringName) -> Button:
	for node: SkillNodeData in _node_buttons:
		if node.id == node_id:
			return _node_buttons[node]
	return null


func selected_node() -> SkillNodeData:
	return _selected


func select_node(node: SkillNodeData) -> void:
	_selected = node
	if node != null:
		_node_buttons[node].button_pressed = true
	_show_details()


## Spends a point on the selected node, when it can be learned.
func learn_selected() -> void:
	if _selected == null or not _progress.can_learn(_selected, RunState.player):
		return
	_progress.learn(_selected, RunState.player)
	_refresh()


func _create_column(branch: SkillBranchData) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = branch.id.to_pascal_case() + "Column"
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label: Label = Label.new()
	name_label.text = branch.display_name
	name_label.add_theme_font_size_override("font_size", BRANCH_NAME_FONT_SIZE)
	column.add_child(name_label)
	var description_label: Label = Label.new()
	description_label.text = branch.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", BRANCH_DESCRIPTION_FONT_SIZE)
	description_label.add_theme_color_override("font_color", CharacterSheet.DESCRIPTION_COLOR)
	column.add_child(description_label)
	for node: SkillNodeData in branch.nodes:
		var button: Button = Button.new()
		button.name = node.id.to_pascal_case() + "Button"
		button.toggle_mode = true
		button.button_group = _button_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select_node.bind(node))
		column.add_child(button)
		_node_buttons[node] = button
	_columns_by_branch[branch] = column
	return column


func _first_learnable_node() -> SkillNodeData:
	for node: SkillNodeData in _node_buttons:
		if _progress.can_learn(node, RunState.player):
			return node
	return null


func _refresh() -> void:
	var level: int = RunState.player.level
	for branch: SkillBranchData in _columns_by_branch:
		var is_open: bool = _progress.is_branch_open(branch, level)
		var is_closed_for_run: bool = not is_open and _progress.specialization != null
		_columns_by_branch[branch].modulate = (
			CLOSED_BRANCH_MODULATE if is_closed_for_run else Color.WHITE
		)
	for node: SkillNodeData in _node_buttons:
		_refresh_node_button(node, level)
	_hint_label.text = _hint_text()
	_show_details()
	if _progress.points_available(RunState.player) == 0:
		_continue_button.grab_focus()


func _refresh_node_button(node: SkillNodeData, level: int) -> void:
	var button: Button = _node_buttons[node]
	var rank: int = _progress.rank_of(node)
	var skill: SkillData = node.ranks[0]
	button.text = "%s  %d/%d" % [skill.display_name, rank, node.ranks.size()]
	if level < node.min_level:
		button.text += "  (level %d)" % node.min_level
	var color: Color = Color.WHITE
	if rank > 0:
		color = LEARNED_COLOR
	elif not _progress.is_unlocked(node, level):
		color = LOCKED_COLOR
	for state: String in ["font_color", "font_pressed_color", "font_hover_color"]:
		button.add_theme_color_override(state, color)


func _hint_text() -> String:
	var points: int = _progress.points_available(RunState.player)
	var text: String = "Level %d   ·   Skill points: %d" % [RunState.player.level, points]
	if _progress.specialization != null:
		return text + "   ·   Specialization: %s" % _progress.specialization.display_name
	if _progress.tree.specialization_level > RunState.player.level:
		return (
			text + "   ·   Specializations open at level %d." % _progress.tree.specialization_level
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
	var rank: int = _progress.rank_of(_selected)
	var shown: SkillData = _progress.next_rank_skill(_selected)
	if shown == null:
		shown = _progress.current_rank_skill(_selected)
	_node_name_label.text = (
		"%s   ·   rank %d/%d" % [shown.display_name, rank, _selected.ranks.size()]
	)
	_node_details_label.text = "\n".join(_detail_lines(shown))
	_learn_button.disabled = not _progress.can_learn(_selected, RunState.player)
	_learn_button.text = "Maxed" if _progress.is_maxed(_selected) else "Learn"


func _detail_lines(shown: SkillData) -> Array[String]:
	var lines: Array[String] = ["%s   %s" % [_describe_activation(shown), shown.description]]
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
	var blockers: Array[String] = _blocker_texts()
	if not blockers.is_empty():
		lines.append(" · ".join(blockers))
	return lines


func _describe_activation(skill: SkillData) -> String:
	if skill.activation == SkillData.Activation.PASSIVE:
		return "Passive."
	return "Active, %d Momentum." % skill.momentum_cost


# Why the node cannot be learned yet, in the player's words.
func _blocker_texts() -> Array[String]:
	var texts: Array[String] = []
	var level: int = RunState.player.level
	var branch: SkillBranchData = _progress.branch_of(_selected)
	if not _progress.is_branch_open(branch, level):
		if _progress.specialization != null:
			texts.append("Closed: you chose %s." % _progress.specialization.display_name)
		else:
			texts.append("Opens at level %d." % _progress.tree.specialization_level)
	if level < _selected.min_level:
		texts.append("Needs level %d." % _selected.min_level)
	if not _progress.is_requirement_met(_selected):
		var required: SkillNodeData = _progress.find_node(branch, _selected.required_node)
		texts.append("Needs %s." % required.ranks[_selected.required_rank - 1].display_name)
	return texts


func _on_continue_pressed() -> void:
	# Disabled first, so a second press cannot advance the room twice.
	_continue_button.disabled = true
	RunState.advance_room()
	get_tree().change_scene_to_file(LevelUp.room_scene_path())
