class_name RunEnd
extends Control
## Run end screen after the boss win or a death: the result of the run and the way into a new one.

const STARTING_CLASS: ClassData = preload("res://scripts/data/classes/warrior.tres")
const ITEM_SLOT_SCENE: PackedScene = preload("res://scenes/ui/item_slot.tscn")
# The battle scene leads here, so a preload of it would form a cycle.
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const VICTORY_TITLE: String = "Victory!"
const DEFEAT_TITLE: String = "You have fallen."

@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _equipment_strip: HBoxContainer = %EquipmentStrip
@onready var _skills_label: Label = %SkillsLabel
@onready var _new_run_button: Button = %NewRunButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	_new_run_button.pressed.connect(_on_new_run_button_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	_show_result()
	_new_run_button.grab_focus()


## A run ends either with the boss win, where the player is still alive, or with a death.
func is_victory() -> bool:
	return RunState.player.is_alive()


func _show_result() -> void:
	var player: Character = RunState.player
	var room_count: int = RunState.GAME_RULES.room_count
	_title_label.text = VICTORY_TITLE if is_victory() else DEFEAT_TITLE
	var room_line: String = "Reached room %d of %d" % [RunState.room_number, room_count]
	if is_victory():
		room_line = "Cleared all %d rooms" % room_count
	_summary_label.text = (
		"%s   ·   Level %d   ·   Run seed: %d" % [room_line, player.level, RunState.run_seed]
	)
	for slot: ItemData.Slot in PaperDoll.SLOT_SIDES:
		var item_slot: ItemSlot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
		item_slot.show_item(slot, player.item_in_slot(slot))
		_equipment_strip.add_child(item_slot)
	_skills_label.text = "Skills: " + ", ".join(_skill_names(player.skills))


## Stacked skills appear once with their count, for example "Strength Training ×2".
func _skill_names(skills: Array[SkillData]) -> PackedStringArray:
	var counts: Dictionary[SkillData, int] = {}
	for skill: SkillData in skills:
		counts[skill] = counts.get(skill, 0) + 1
	var names: PackedStringArray = []
	for skill: SkillData in counts:
		var count: int = counts[skill]
		names.append(skill.display_name if count == 1 else "%s ×%d" % [skill.display_name, count])
	return names


func _on_new_run_button_pressed() -> void:
	RunState.start_new_run(STARTING_CLASS, RunState.new_random_seed())
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
