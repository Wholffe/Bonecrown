class_name RestScreen
extends Control
## A rest site on the map: the node's level-up, then healing by the fire.

@onready var _level_up_label: Label = %LevelUpLabel
@onready var _heal_label: Label = %HealLabel
@onready var _hit_points_label: Label = %HitPointsLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _character_button: Button = %CharacterButton
@onready var _character_sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
	_continue_button.pressed.connect(_on_continue_pressed)
	var rewards: RoomRewards = RunState.start_room_rewards()
	rewards.level_up()
	_level_up_label.text = LevelUp.level_up_text(rewards)
	# After the level-up, so the rest heals a share of the new max HP.
	var healed: int = RunState.create_map_events().rest(RunState.player)
	_heal_label.text = "You rest by the fire: +%d HP" % healed
	_hit_points_label.text = (
		"HP %d / %d" % [RunState.player.hit_points, RunState.player.max_hit_points]
	)
	_continue_button.text = MapScreen.next_step_text()
	_continue_button.grab_focus()


func _on_continue_pressed() -> void:
	# Disabled first, so a second press cannot change the scene twice.
	_continue_button.disabled = true
	get_tree().change_scene_to_file(MapScreen.scene_after_node())
