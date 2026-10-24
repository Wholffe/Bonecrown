extends Control
## Title screen that starts a new run.

const STARTING_CLASS: ClassData = preload("res://scripts/data/classes/warrior.tres")

@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)
	_start_button.grab_focus()


func _on_start_button_pressed() -> void:
	RunState.start_new_run(STARTING_CLASS, RunState.new_random_seed())
	get_tree().change_scene_to_file(MapScreen.MAP_SCENE_PATH)
