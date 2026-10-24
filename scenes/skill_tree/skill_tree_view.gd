class_name SkillTreeView
extends Control
## The skill tree drawn as a tree: the trunk at the bottom, the specializations branching upward,
## nodes as circles with their rank. A branch grows as a bough from its first node, and the nodes
## that build on it hang from the bough on twigs.

signal node_pressed(node: SkillNodeData)

const NODE_SIZE: float = 52.0
const NAME_WIDTH: float = 116.0
const NAME_HEIGHT: float = 36.0
const NAME_FONT_SIZE: int = 13
const RANK_FONT_SIZE: int = 15
const BRANCH_TITLE_HEIGHT: float = 64.0
const BRANCH_TITLE_MARGIN: float = 8.0
const BRANCH_NAME_FONT_SIZE: int = 20
const BRANCH_DESCRIPTION_FONT_SIZE: int = 12
## The trunk spreads its nodes over this share of the width, centered on the trunk line.
const TRUNK_WIDTH_SHARE: float = 0.6
const TRUNK_LINE_WIDTH: float = 12.0
const TWIG_WIDTH: float = 4.0
const BRANCH_LINE_WIDTH: float = 6.0
const EDGE_WIDTH: float = 3.0
const BORDER_WIDTH: int = 2
const SELECTED_BORDER_WIDTH: int = 4
const HOVER_LIGHTEN: float = 0.15
## A lone node below the top row hangs off the bough instead of sitting on it, so the bough does
## not seem to lead through it.
const SIDE_SLOT_SHARE: float = 0.3
## Names get an outline in the background color, so lines behind them do not cut the letters.
const NAME_OUTLINE_SIZE: int = 6
const NAME_OUTLINE_COLOR: Color = Color(0.1, 0.1, 0.12)
const LEARNED_COLOR: Color = Color(1.0, 0.82, 0.35)
const AVAILABLE_COLOR: Color = Color(0.9, 0.93, 1.0)
const OPEN_COLOR: Color = Color(0.62, 0.64, 0.7)
const LOCKED_COLOR: Color = Color(0.36, 0.36, 0.4)
const TRUNK_COLOR: Color = Color(0.42, 0.31, 0.2)
const NODE_FILL_COLOR: Color = Color(0.15, 0.16, 0.19)
const LEARNED_FILL_COLOR: Color = Color(0.33, 0.25, 0.08)
const SELECTED_BORDER_COLOR: Color = Color.WHITE
## A closed specialization darkens, so the chosen one stands out. It stays opaque, so the lines
## behind its nodes do not show through.
const CLOSED_BRANCH_MODULATE: Color = Color(0.55, 0.55, 0.6)

var _progress: SkillTreeProgress
var _character: Character
var _buttons: Dictionary[SkillNodeData, Button] = {}
var _name_labels: Dictionary[SkillNodeData, Label] = {}
var _layers: Dictionary[SkillBranchData, Control] = {}
var _titles: Dictionary[SkillBranchData, Label] = {}
## Row of each node. In the trunk a row is a tier, in a specialization row 0 holds the nodes that
## start the branch.
var _rows: Dictionary[SkillNodeData, int] = {}
var _branch_row_count: int = 0
var _trunk_row_count: int = 0
var _fork_point: Vector2 = Vector2.ZERO
var _button_group: ButtonGroup = ButtonGroup.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _progress != null:
		_layout()


func build(progress: SkillTreeProgress) -> void:
	_progress = progress
	for branch: SkillBranchData in progress.branches():
		var layer: Control = Control.new()
		layer.name = branch.id.to_pascal_case() + "Branch"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_create_title(branch))
		for node: SkillNodeData in branch.nodes:
			layer.add_child(_create_node_button(node))
		_layers[branch] = layer
	_assign_rows()
	_layout()


func node_button(node_id: StringName) -> Button:
	for node: SkillNodeData in _buttons:
		if node.id == node_id:
			return _buttons[node]
	return null


func branch_layer(branch_id: StringName) -> Control:
	for branch: SkillBranchData in _layers:
		if branch.id == branch_id:
			return _layers[branch]
	return null


func select(node: SkillNodeData) -> void:
	if node != null:
		_buttons[node].button_pressed = true


## Colors every node and line for the character's level and learned ranks.
func refresh(character: Character) -> void:
	_character = character
	for branch: SkillBranchData in _layers:
		_layers[branch].modulate = (CLOSED_BRANCH_MODULATE if _is_closed(branch) else Color.WHITE)
		var title_color: Color = (
			LEARNED_COLOR if branch == _progress.specialization else Color.WHITE
		)
		_titles[branch].add_theme_color_override("font_color", title_color)
	for node: SkillNodeData in _buttons:
		_style_node(node)
	queue_redraw()


func _draw() -> void:
	if _progress == null:
		return
	var trunk_x: float = size.x / 2.0
	draw_line(Vector2(trunk_x, size.y), _fork_point, TRUNK_COLOR, TRUNK_LINE_WIDTH)
	for node: SkillNodeData in _progress.tree.trunk.nodes:
		var center: Vector2 = _center(node)
		draw_line(Vector2(trunk_x, center.y), center, TRUNK_COLOR, TWIG_WIDTH)
	for branch: SkillBranchData in _progress.tree.specializations:
		for node: SkillNodeData in branch.nodes:
			if node.required_node == &"":
				draw_line(_fork_point, _center(node), _edge_color(branch, node), BRANCH_LINE_WIDTH)
				_draw_bough(branch, node)
			elif _progress.find_node(branch, node.required_node).required_node != &"":
				# A node that builds on a twig node gets a direct line to it.
				var required: SkillNodeData = _progress.find_node(branch, node.required_node)
				draw_line(_center(required), _center(node), _edge_color(branch, node), EDGE_WIDTH)


# The bough rises from the first node to the highest node that builds on it, and every such node
# hangs from it on a level twig.
func _draw_bough(branch: SkillBranchData, root: SkillNodeData) -> void:
	var start: Vector2 = _center(root)
	var top: float = start.y
	for node: SkillNodeData in branch.nodes:
		if node.required_node == root.id:
			top = minf(top, _center(node).y)
			var center: Vector2 = _center(node)
			draw_line(Vector2(start.x, center.y), center, _edge_color(branch, node), EDGE_WIDTH)
	draw_line(start, Vector2(start.x, top), _edge_color(branch, root), BRANCH_LINE_WIDTH)


func _create_title(branch: SkillBranchData) -> Label:
	var title: Label = Label.new()
	title.name = "Title"
	title.text = branch.display_name
	title.add_theme_font_size_override("font_size", BRANCH_NAME_FONT_SIZE)
	var description: Label = Label.new()
	description.text = branch.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", BRANCH_DESCRIPTION_FONT_SIZE)
	description.add_theme_color_override("font_color", CharacterSheet.DESCRIPTION_COLOR)
	description.position = Vector2(0, BRANCH_NAME_FONT_SIZE + BRANCH_TITLE_MARGIN)
	title.add_child(description)
	_titles[branch] = title
	return title


func _create_node_button(node: SkillNodeData) -> Button:
	var button: Button = Button.new()
	button.name = node.id.to_pascal_case() + "Button"
	button.toggle_mode = true
	button.button_group = _button_group
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.add_theme_font_size_override("font_size", RANK_FONT_SIZE)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(node_pressed.emit.bind(node))
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.position = Vector2((NODE_SIZE - NAME_WIDTH) / 2.0, NODE_SIZE + 2.0)
	name_label.size = Vector2(NAME_WIDTH, NAME_HEIGHT)
	name_label.add_theme_constant_override("outline_size", NAME_OUTLINE_SIZE)
	name_label.add_theme_color_override("font_outline_color", NAME_OUTLINE_COLOR)
	button.add_child(name_label)
	_buttons[node] = button
	_name_labels[node] = name_label
	return button


# Rows follow the levels of the nodes that build on others, so equal levels line up across the
# specializations. Nodes that start a branch sit in the lowest row, next to the trunk.
func _assign_rows() -> void:
	var levels: Array[int] = []
	for branch: SkillBranchData in _progress.tree.specializations:
		for node: SkillNodeData in branch.nodes:
			if node.required_node != &"" and not node.min_level in levels:
				levels.append(node.min_level)
	levels.sort()
	for branch: SkillBranchData in _progress.tree.specializations:
		for node: SkillNodeData in branch.nodes:
			_rows[node] = 0 if node.required_node == &"" else 1 + levels.find(node.min_level)
	_branch_row_count = 1 + levels.size()
	var tiers: Array[int] = []
	for node: SkillNodeData in _progress.tree.trunk.nodes:
		if not node.required_branch_ranks in tiers:
			tiers.append(node.required_branch_ranks)
	tiers.sort()
	for node: SkillNodeData in _progress.tree.trunk.nodes:
		_rows[node] = tiers.find(node.required_branch_ranks)
	_trunk_row_count = tiers.size()


func _layout() -> void:
	var trunk: SkillBranchData = _progress.tree.trunk
	var trunk_rows: int = _trunk_row_count
	var row_height: float = (size.y - BRANCH_TITLE_HEIGHT) / (_branch_row_count + trunk_rows)
	var trunk_width: float = size.x * TRUNK_WIDTH_SHARE
	var trunk_left: float = (size.x - trunk_width) / 2.0
	for row: int in trunk_rows:
		var row_nodes: Array[SkillNodeData] = _nodes_in_row(trunk, row)
		for slot: int in row_nodes.size():
			_place(
				row_nodes[slot],
				Vector2(
					trunk_left + (slot + 0.5) * trunk_width / row_nodes.size(),
					size.y - (row + 0.5) * row_height
				)
			)
	_place_trunk_title(trunk, trunk_left, size.y - trunk_rows * row_height)
	_fork_point = Vector2(size.x / 2.0, size.y - trunk_rows * row_height)
	var column_width: float = size.x / _progress.tree.specializations.size()
	for column: int in _progress.tree.specializations.size():
		var branch: SkillBranchData = _progress.tree.specializations[column]
		var left: float = column * column_width
		_titles[branch].position = Vector2(left + BRANCH_TITLE_MARGIN, 0)
		_titles[branch].get_child(0).size = Vector2(column_width - 2 * BRANCH_TITLE_MARGIN, 0)
		var top_row: int = _top_row(branch)
		for row: int in _branch_row_count:
			var row_nodes: Array[SkillNodeData] = _nodes_in_row(branch, row)
			for slot: int in row_nodes.size():
				var share: float = (slot + 0.5) / row_nodes.size()
				if row_nodes.size() == 1 and row != 0 and row != top_row:
					share = SIDE_SLOT_SHARE if row % 2 == 1 else 1.0 - SIDE_SLOT_SHARE
				_place(
					row_nodes[slot],
					Vector2(
						left + share * column_width, size.y - (trunk_rows + row + 0.5) * row_height
					)
				)
	queue_redraw()


func _place_trunk_title(trunk: SkillBranchData, width: float, top: float) -> void:
	var title: Label = _titles[trunk]
	title.position = Vector2(0, top)
	title.get_child(0).size = Vector2(width - BRANCH_TITLE_MARGIN, 0)


func _place(node: SkillNodeData, center: Vector2) -> void:
	_buttons[node].position = center - Vector2(NODE_SIZE, NODE_SIZE) / 2.0


func _nodes_in_row(branch: SkillBranchData, row: int) -> Array[SkillNodeData]:
	var nodes: Array[SkillNodeData] = []
	for node: SkillNodeData in branch.nodes:
		if _rows[node] == row:
			nodes.append(node)
	return nodes


func _top_row(branch: SkillBranchData) -> int:
	var top: int = 0
	for node: SkillNodeData in branch.nodes:
		top = maxi(top, _rows[node])
	return top


func _center(node: SkillNodeData) -> Vector2:
	return _buttons[node].position + Vector2(NODE_SIZE, NODE_SIZE) / 2.0


# Closed for the rest of the run: another specialization was chosen. The trunk never closes.
func _is_closed(branch: SkillBranchData) -> bool:
	return (
		branch != _progress.tree.trunk
		and _progress.specialization != null
		and branch != _progress.specialization
	)


func _state_color(node: SkillNodeData) -> Color:
	if _progress.rank_of(node) > 0:
		return LEARNED_COLOR
	if _character != null and _progress.can_learn(node, _character):
		return AVAILABLE_COLOR
	if _character != null and _progress.is_unlocked(node, _character.level):
		return OPEN_COLOR
	return LOCKED_COLOR


func _edge_color(branch: SkillBranchData, node: SkillNodeData) -> Color:
	var color: Color = _state_color(node)
	return color * CLOSED_BRANCH_MODULATE if _is_closed(branch) else color


func _style_node(node: SkillNodeData) -> void:
	var button: Button = _buttons[node]
	var color: Color = _state_color(node)
	var fill: Color = LEARNED_FILL_COLOR if _progress.rank_of(node) > 0 else NODE_FILL_COLOR
	# Before its level the circle names the level instead of the rank, which is 0 then anyway.
	button.text = "%d/%d" % [_progress.rank_of(node), node.ranks.size()]
	if _character != null and _character.level < node.min_level:
		button.text = "Lv %d" % node.min_level
	button.add_theme_stylebox_override("normal", _circle(fill, color, BORDER_WIDTH))
	button.add_theme_stylebox_override(
		"hover", _circle(fill.lightened(HOVER_LIGHTEN), color, BORDER_WIDTH)
	)
	button.add_theme_stylebox_override(
		"pressed", _circle(fill, SELECTED_BORDER_COLOR, SELECTED_BORDER_WIDTH)
	)
	button.add_theme_stylebox_override(
		"hover_pressed",
		_circle(fill.lightened(HOVER_LIGHTEN), SELECTED_BORDER_COLOR, SELECTED_BORDER_WIDTH)
	)
	for state: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"
	]:
		button.add_theme_color_override(state, color)
	var name_label: Label = _name_labels[node]
	name_label.text = node.ranks[0].display_name
	name_label.add_theme_color_override("font_color", color)


func _circle(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(NODE_SIZE / 2.0))
	style.anti_aliasing = true
	return style
