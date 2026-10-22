class_name CharacterSheet
extends Control
## Overlay with the character's values, skills and items. The C key or its button toggles it.
## The items are shown on a paper doll, the figure wearing them.

const TOGGLE_KEY: Key = KEY_C
const HIT_POINTS_LABEL: String = "HP"
## Shared with the skill cards of the post-fight screen.
const DESCRIPTION_COLOR: Color = Color(0.7, 0.7, 0.75)

## Set once by the scene that adds the sheet. The content is rebuilt on every open().
var character: Character
## While locked, the sheet does not open, for example while a battle turn plays back.
var is_locked: bool = false

@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _skills_box: VBoxContainer = %SkillsBox
@onready var _paper_doll: PaperDoll = %PaperDoll
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	_close_button.pressed.connect(hide)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		hide()
	else:
		open()


func open() -> void:
	assert(character != null, "Set the character before opening the sheet")
	if is_locked:
		return
	_show_stats()
	_show_skills()
	_paper_doll.show_character(character)
	show()
	# Keys such as Enter must not reach the buttons behind the sheet.
	_close_button.grab_focus()


## The text of a stat row, for example "+5" for "Attack". Empty if the row does not exist.
func stat_text(label: String) -> String:
	for index: int in range(0, _stats_grid.get_child_count(), 2):
		if (_stats_grid.get_child(index) as Label).text == label:
			return (_stats_grid.get_child(index + 1) as Label).text
	return ""


## Every text in the skill list and the names of the worn items, for tests.
func listed_texts() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in _skills_box.get_children():
		texts.append((child as Label).text)
	for slot: ItemData.Slot in PaperDoll.SLOT_SIDES:
		var item: ItemData = _paper_doll.item_slot(slot).item
		if item != null:
			texts.append(item.display_name)
	return texts


func _show_stats() -> void:
	_clear(_stats_grid)
	_add_stat(HIT_POINTS_LABEL, "%d / %d" % [character.hit_points, character.max_hit_points])
	var sheet: StatSheet = StatSheet.new(character)
	for label: String in sheet.labels:
		_add_stat(label, sheet.value_of(label))


func _show_skills() -> void:
	_clear(_skills_box)
	# Stackable skills learned more than once are listed once with their count.
	var counts: Dictionary[StringName, int] = {}
	var unique_skills: Array[SkillData] = []
	for skill: SkillData in character.skills:
		if not counts.has(skill.id):
			unique_skills.append(skill)
		counts[skill.id] = counts.get(skill.id, 0) + 1
	for skill: SkillData in unique_skills:
		var title: String = skill.display_name
		if counts[skill.id] > 1:
			title += " ×%d" % counts[skill.id]
		_add_entry(_skills_box, title, skill.description)


func _add_stat(label: String, value: String) -> void:
	var name_label: Label = Label.new()
	name_label.text = label
	_stats_grid.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_grid.add_child(value_label)


func _add_entry(box: VBoxContainer, title: String, description: String) -> void:
	var title_label: Label = Label.new()
	title_label.text = title
	box.add_child(title_label)
	if description.is_empty():
		return
	var description_label: Label = Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_color_override("font_color", DESCRIPTION_COLOR)
	box.add_child(description_label)


# free() instead of queue_free(), so the rebuilt content is complete within the same frame.
func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.free()
