class_name MapView
extends Control
## The run's map drawn from left to right, one column per room: the paths between the nodes, the
## path walked so far, the nodes the player can enter next, and everything the selected node still
## leads to, so the player sees which path reaches which merchant, rest or treasure.

signal node_pressed(node: MapNode)

const NODE_SIZE: float = 46.0
const NAME_WIDTH: float = 100.0
const NAME_HEIGHT: float = 34.0
const NAME_FONT_SIZE: int = 13
const NAME_OUTLINE_SIZE: int = 6
const BACKGROUND_COLOR: Color = Color(0.1, 0.1, 0.12)
const NODE_FILL_COLOR: Color = Color(0.15, 0.16, 0.19)
const EDGE_WIDTH: float = 3.0
const WALKED_EDGE_WIDTH: float = 6.0
const BORDER_WIDTH: int = 2
const SELECTED_BORDER_WIDTH: int = 5
## Room for the first and last column's names at the left and right edge.
const SIDE_MARGIN: float = 56.0
const WALKED_COLOR: Color = Color(1.0, 0.82, 0.35)
const AVAILABLE_COLOR: Color = Color.WHITE
const EDGE_COLOR: Color = Color(0.45, 0.46, 0.52)
const LEADS_TO_COLOR: Color = Color(0.85, 0.88, 0.95)
## Nodes the player can no longer reach fade.
const UNREACHABLE_MODULATE: Color = Color(0.4, 0.4, 0.45)
const TYPE_NAMES: Dictionary[MapNode.Type, String] = {
	MapNode.Type.FIGHT: "Fight",
	MapNode.Type.ELITE: "Elite",
	MapNode.Type.MERCHANT: "Merchant",
	MapNode.Type.REST: "Rest",
	MapNode.Type.TREASURE: "Treasure",
	MapNode.Type.BOSS: "Boss",
}
const TYPE_ICONS: Dictionary[MapNode.Type, Texture2D] = {
	MapNode.Type.FIGHT: preload("res://assets/sprites/dungeon/weapon_regular_sword.png"),
	MapNode.Type.ELITE: preload("res://assets/sprites/dungeon/skull.png"),
	MapNode.Type.MERCHANT: preload("res://assets/sprites/dungeon/coin_anim_f0.png"),
	MapNode.Type.REST: preload("res://assets/sprites/dungeon/flask_big_red.png"),
	MapNode.Type.TREASURE: preload("res://assets/sprites/dungeon/chest_full_open_anim_f0.png"),
	MapNode.Type.BOSS: preload("res://assets/sprites/dungeon/necromancer_anim_f0.png"),
}
## Room between the circle's edge and the icon inside it.
const ICON_MARGIN: int = 10
const TYPE_COLORS: Dictionary[MapNode.Type, Color] = {
	MapNode.Type.FIGHT: Color(0.8, 0.8, 0.85),
	MapNode.Type.ELITE: Color(0.95, 0.45, 0.35),
	MapNode.Type.MERCHANT: Color(1.0, 0.82, 0.35),
	MapNode.Type.REST: Color(0.5, 0.85, 0.5),
	MapNode.Type.TREASURE: Color(0.55, 0.72, 1.0),
	MapNode.Type.BOSS: Color(0.9, 0.3, 0.35),
}

var _map: RunMap
var _buttons: Dictionary[MapNode, Button] = {}
var _available: Array[MapNode] = []
var _walked: Array[MapNode] = []
var _reachable: Array[MapNode] = []
var _leads_to: Array[MapNode] = []
var _button_group: ButtonGroup = ButtonGroup.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _map != null:
		_layout()


func build(map: RunMap) -> void:
	_map = map
	for node: MapNode in map.nodes:
		add_child(_create_node_button(node))
	_layout()


func node_button(row: int, lane: int) -> Button:
	var node: MapNode = _map.node_at(row, lane)
	return _buttons[node] if node != null else null


## Shows the walked path, the nodes the player can enter now and what stays reachable.
func refresh(available: Array[MapNode], walked: Array[MapNode]) -> void:
	_available = available
	_walked = walked
	_reachable = reachable_from(available)
	for node: MapNode in _buttons:
		_style_node(node)
	queue_redraw()


## Selects the node and highlights every node it still leads to.
func select(node: MapNode) -> void:
	if node == null:
		_leads_to = []
	else:
		_buttons[node].button_pressed = true
		var from: Array[MapNode] = [node]
		_leads_to = reachable_from(from)
	for candidate: MapNode in _buttons:
		_style_node(candidate)
	queue_redraw()


## The nodes and every node after them.
static func reachable_from(nodes: Array[MapNode]) -> Array[MapNode]:
	var reachable: Array[MapNode] = []
	var open: Array[MapNode] = nodes.duplicate()
	while not open.is_empty():
		var node: MapNode = open.pop_back()
		if node in reachable:
			continue
		reachable.append(node)
		open.append_array(node.next_nodes)
	return reachable


func _draw() -> void:
	if _map == null:
		return
	for node: MapNode in _map.nodes:
		for next: MapNode in node.next_nodes:
			var color: Color = EDGE_COLOR
			var width: float = EDGE_WIDTH
			if node in _walked and next in _walked:
				color = WALKED_COLOR
				width = WALKED_EDGE_WIDTH
			elif node in _leads_to and next in _leads_to:
				color = LEADS_TO_COLOR
			elif not next in _reachable:
				color = EDGE_COLOR * UNREACHABLE_MODULATE
			draw_line(_center(node), _center(next), color, width, true)


func _create_node_button(node: MapNode) -> Button:
	var button: Button = Button.new()
	button.name = "Node%d_%d" % [node.row, node.lane]
	button.toggle_mode = true
	button.button_group = _button_group
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.icon = TYPE_ICONS[node.type]
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Pixel art stays crisp only without filtering. The name below is text and stays smooth.
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(node_pressed.emit.bind(node))
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = TYPE_NAMES[node.type]
	if node.check != null:
		name_label.text = "Sealed " + name_label.text
	name_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_constant_override("outline_size", NAME_OUTLINE_SIZE)
	name_label.add_theme_color_override("font_outline_color", BACKGROUND_COLOR)
	name_label.position = Vector2((NODE_SIZE - NAME_WIDTH) / 2.0, NODE_SIZE + 2.0)
	name_label.size = Vector2(NAME_WIDTH, NAME_HEIGHT)
	button.add_child(name_label)
	_buttons[node] = button
	return button


func _layout() -> void:
	var column_step: float = (size.x - 2.0 * SIDE_MARGIN) / maxi(_map.row_count - 1, 1)
	var lane_height: float = size.y / _map.lane_count
	for node: MapNode in _map.nodes:
		var y: float = (node.lane + 0.5) * lane_height
		# A row with one node sits in the middle, where all paths meet.
		if _map.nodes_in_row(node.row).size() == 1:
			y = size.y / 2.0
		var center: Vector2 = Vector2(SIDE_MARGIN + (node.row - RunMap.FIRST_ROW) * column_step, y)
		_buttons[node].position = center - Vector2(NODE_SIZE, NODE_SIZE) / 2.0
	queue_redraw()


func _center(node: MapNode) -> Vector2:
	return _buttons[node].position + Vector2(NODE_SIZE, NODE_SIZE) / 2.0


func _style_node(node: MapNode) -> void:
	var button: Button = _buttons[node]
	var type_color: Color = TYPE_COLORS[node.type]
	var border: Color = type_color
	if node in _walked:
		border = WALKED_COLOR
	elif node in _available:
		border = AVAILABLE_COLOR
	button.add_theme_stylebox_override("normal", _circle(border, BORDER_WIDTH))
	button.add_theme_stylebox_override("hover", _circle(border.lightened(0.2), BORDER_WIDTH))
	button.add_theme_stylebox_override("pressed", _circle(border, SELECTED_BORDER_WIDTH))
	button.add_theme_stylebox_override("hover_pressed", _circle(border, SELECTED_BORDER_WIDTH))
	var label: Label = button.get_node("NameLabel") as Label
	label.add_theme_color_override("font_color", type_color)
	var is_open: bool = node in _walked or node in _reachable
	button.modulate = Color.WHITE if is_open else UNREACHABLE_MODULATE


func _circle(border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = NODE_FILL_COLOR
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(NODE_SIZE / 2.0))
	style.set_content_margin_all(ICON_MARGIN)
	style.anti_aliasing = true
	return style
