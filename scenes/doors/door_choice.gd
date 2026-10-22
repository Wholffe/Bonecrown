class_name DoorChoice
extends Control
## Pre-fight screen: the doors of the room with their enemies and rewards, each with Enter.

const DOOR_TITLES: Array[String] = ["Left Door", "Right Door"]
const REWARD_COLOR: Color = Color(1.0, 0.82, 0.2)
# A path instead of a preload, because the post-fight screen leads here and the battle scene
# leads there, so a preload would form a cycle.
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle.tscn"

var _doors: Array[DoorOption] = []
var _enter_buttons: Array[Button] = []

@onready var _title_label: Label = %TitleLabel
@onready var _hit_points_label: Label = %HitPointsLabel
@onready var _door_cards: HBoxContainer = %DoorCards


func _ready() -> void:
	_doors = RunState.roll_doors()
	_title_label.text = "Room %d" % RunState.room_number
	_hit_points_label.text = (
		"HP %d/%d" % [RunState.player.hit_points, RunState.player.max_hit_points]
	)
	for index: int in _doors.size():
		_door_cards.add_child(_create_door_card(_doors[index], index))
	if not _enter_buttons.is_empty():
		_enter_buttons[0].grab_focus()


## For example "Elite Orc · AC 11 · HP 28 · Attack +7 · 1d10+2".
static func enemy_line(enemy: Combatant) -> String:
	return (
		"%s · AC %d · HP %d · Attack %+d · %s"
		% [
			enemy.display_name,
			enemy.get_armor_class(),
			enemy.max_hit_points,
			enemy.get_attack_bonus(),
			StatSheet.dice_text(
				enemy.get_damage_die_count(), enemy.get_damage_die_sides(), enemy.get_damage_bonus()
			),
		]
	)


## The doors in card order.
func doors() -> Array[DoorOption]:
	return _doors


## Records the door for the fight. Entering it also changes to the battle scene.
func choose_door(door: DoorOption) -> void:
	RunState.choose_door(door)
	for button: Button in _enter_buttons:
		button.disabled = true


func _create_door_card(door: DoorOption, index: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout: VBoxContainer = VBoxContainer.new()
	card.add_child(layout)
	var title_label: Label = Label.new()
	title_label.text = _door_title(index)
	title_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(title_label)
	for enemy: Combatant in door.enemies:
		layout.add_child(_create_line_label(enemy_line(enemy)))
	if door.reward != null:
		var reward_label: Label = _create_line_label(
			"%s: %s" % [door.reward.display_name, door.reward.description]
		)
		reward_label.add_theme_color_override("font_color", REWARD_COLOR)
		layout.add_child(reward_label)
	var button: Button = Button.new()
	button.text = "Enter"
	button.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	button.pressed.connect(_on_enter_pressed.bind(door))
	layout.add_child(button)
	_enter_buttons.append(button)
	return card


func _create_line_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


# More doors than titles only happen when the room table asks for them.
func _door_title(index: int) -> String:
	if index < DOOR_TITLES.size():
		return DOOR_TITLES[index]
	return "Door %d" % (index + 1)


func _on_enter_pressed(door: DoorOption) -> void:
	choose_door(door)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
