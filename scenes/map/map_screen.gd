class_name MapScreen
extends Control
## The map between the nodes: the whole run from the first fight to the boss, the selected node's
## details and a button to enter it when the player can go there next.

# Paths instead of preloads: every one of these scenes leads back here, so preloads would form
# cycles.
const MAP_SCENE_PATH: String = "res://scenes/map/map_screen.tscn"
const SKILL_TREE_SCENE_PATH: String = "res://scenes/skill_tree/skill_tree.tscn"
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle.tscn"
const MERCHANT_SCENE_PATH: String = "res://scenes/map/merchant_screen.tscn"
const REST_SCENE_PATH: String = "res://scenes/map/rest_screen.tscn"
## A treasure uses the loot part of the post-fight screen.
const TREASURE_SCENE_PATH: String = "res://scenes/levelup/level_up.tscn"
const LEGEND_TEXT: String = (
	"F Fight   ·   E Elite   ·   $ Merchant   ·   R Rest   ·   T Treasure   ·   B Boss\n"
	+ "Every node gives a level-up. Select a node to see where it leads."
)

var _selected: MapNode = null

@onready var _status_label: Label = %StatusLabel
@onready var _character_button: Button = %CharacterButton
@onready var _map_view: MapView = %MapView
@onready var _node_name_label: Label = %NodeNameLabel
@onready var _node_details_label: Label = %NodeDetailsLabel
@onready var _enter_button: Button = %EnterButton
@onready var _legend_label: Label = %LegendLabel
@onready var _character_sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
	_enter_button.pressed.connect(enter_selected)
	_legend_label.text = LEGEND_TEXT
	_status_label.text = (
		"Level %d   ·   HP %d / %d   ·   Gold %d"
		% [
			RunState.player.level,
			RunState.player.hit_points,
			RunState.player.max_hit_points,
			RunState.player.gold,
		]
	)
	_map_view.build(RunState.map)
	_map_view.node_pressed.connect(select_node)
	_map_view.refresh(RunState.available_nodes(), RunState.walked)
	select_node(RunState.available_nodes()[0])
	_enter_button.grab_focus()


## After a node, the skill tree comes first while a point can be spent there.
static func has_skill_point_to_spend() -> bool:
	var tree: SkillTreeProgress = RunState.skill_tree
	return tree != null and tree.has_learnable_node(RunState.player)


static func scene_after_node() -> String:
	return SKILL_TREE_SCENE_PATH if has_skill_point_to_spend() else MAP_SCENE_PATH


## The text of the button that leaves a node.
static func next_step_text() -> String:
	return "Skill Tree" if has_skill_point_to_spend() else "Map"


static func node_scene_path(node: MapNode) -> String:
	match node.type:
		MapNode.Type.MERCHANT:
			return MERCHANT_SCENE_PATH
		MapNode.Type.REST:
			return REST_SCENE_PATH
		MapNode.Type.TREASURE:
			return TREASURE_SCENE_PATH
	return BATTLE_SCENE_PATH


func selected_node() -> MapNode:
	return _selected


func select_node(node: MapNode) -> void:
	_selected = node
	_map_view.select(node)
	_node_name_label.text = MapView.TYPE_NAMES[node.type]
	if node.check != null:
		_node_name_label.text = "Sealed Treasure: %s" % node.check.display_name
	_node_details_label.text = "\n\n".join(_detail_lines(node))
	_enter_button.disabled = not node in RunState.available_nodes()


## Enters the selected node when the player can go there next.
func enter_selected() -> void:
	if _selected == null or not _selected in RunState.available_nodes():
		return
	# Disabled first, so a second press cannot enter twice.
	_enter_button.disabled = true
	RunState.enter_node(_selected)
	get_tree().change_scene_to_file(node_scene_path(_selected))


func _detail_lines(node: MapNode) -> Array[String]:
	var lines: Array[String] = ["Room %d." % node.row, _description(node)]
	if node.check != null:
		lines.append(_check_text(node.check))
	if node in RunState.walked:
		lines.append("You have been here.")
	elif node in RunState.available_nodes():
		lines.append("You can go here next.")
	elif not node in MapView.reachable_from(RunState.available_nodes()):
		lines.append("You cannot reach this node anymore.")
	return lines


func _description(node: MapNode) -> String:
	var economy: EconomyData = RunState.ECONOMY
	var rooms: RoomTableData = RunState.ROOM_TABLE
	var descriptions: Dictionary[MapNode.Type, String] = {
		MapNode.Type.FIGHT: "A fight. Afterwards gold and a loot roll.",
		MapNode.Type.ELITE:
		(
			"A strong enemy: +%d%% HP and %+d attack. Afterwards %d%% gold and %+d on the loot roll."
			% [
				rooms.elite_hit_point_percent,
				rooms.elite_attack_bonus,
				economy.elite_gold_percent,
				rooms.elite_loot_bonus,
			]
		),
		MapNode.Type.MERCHANT: "Buy items and healing with your gold.",
		MapNode.Type.REST:
		"Rest by the fire and heal %d%% of your max HP." % economy.rest_heal_percent,
		MapNode.Type.TREASURE:
		(
			"No fight: %d gold and a loot roll with %+d."
			% [economy.treasure_gold, economy.treasure_loot_bonus]
		),
		MapNode.Type.BOSS: "The final fight against the boss.",
	}
	return descriptions.get(node.type, "")


func _check_text(check: SkillCheckData) -> String:
	var attribute: String = StatSheet.ATTRIBUTE_LABELS[check.attribute]
	return (
		(
			"Sealed: %s check, d%d%+d against %d. Success: %+d more on the loot roll. Failure: "
			+ "−%d HP and the treasure stays shut."
		)
		% [
			attribute,
			SkillCheckRoll.DIE_SIDES,
			RunState.player.attribute_bonus(check.attribute),
			check.difficulty,
			RunState.ECONOMY.sealed_treasure_loot_bonus,
			check.fail_damage,
		]
	)
