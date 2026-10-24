extends GutTest
## Run end screen: the result of a won or lost run and the buttons into a new one.

const RUN_END_SCENE: PackedScene = preload("res://scenes/run_end/run_end.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const STRENGTH_TRAINING: SkillData = preload("res://scripts/data/skills/strength_training.tres")
const SEED: int = 42


func _show_run_end(room_number: int, player_alive: bool) -> RunEnd:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = room_number
	if not player_alive:
		RunState.player.take_damage(RunState.player.hit_points)
	var run_end: RunEnd = RUN_END_SCENE.instantiate() as RunEnd
	add_child_autofree(run_end)
	return run_end


func _text(run_end: RunEnd, label_name: String) -> String:
	return (run_end.get_node("%" + label_name) as Label).text


func test_death_shows_the_room_reached() -> void:
	var run_end: RunEnd = _show_run_end(4, false)

	assert_false(run_end.is_victory())
	assert_eq(_text(run_end, "TitleLabel"), RunEnd.DEFEAT_TITLE)
	var summary: String = _text(run_end, "SummaryLabel")
	assert_string_contains(summary, "Reached room 4 of 10")
	assert_string_contains(summary, "Level 1")
	assert_string_contains(summary, "Run seed: %d" % SEED)


func test_boss_win_shows_the_cleared_run() -> void:
	var run_end: RunEnd = _show_run_end(RunState.GAME_RULES.room_count, true)

	assert_true(run_end.is_victory())
	assert_eq(_text(run_end, "TitleLabel"), RunEnd.VICTORY_TITLE)
	assert_string_contains(_text(run_end, "SummaryLabel"), "Cleared all 10 rooms")


func test_stacked_skills_appear_once_with_their_count() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.player.learn_skill(STRENGTH_TRAINING)
	RunState.player.learn_skill(STRENGTH_TRAINING)
	var run_end: RunEnd = RUN_END_SCENE.instantiate() as RunEnd
	add_child_autofree(run_end)

	var skills: String = _text(run_end, "SkillsLabel")
	assert_string_contains(skills, "Second Wind")
	assert_string_contains(skills, "Strength Training ×2")
	assert_eq(skills.count("Strength Training"), 1)


func test_equipment_strip_shows_every_slot() -> void:
	var run_end: RunEnd = _show_run_end(4, false)

	var strip: Node = run_end.get_node("%EquipmentStrip")
	assert_eq(strip.get_child_count(), PaperDoll.SLOT_SIDES.size())
	for child: Node in strip.get_children():
		var item_slot: ItemSlot = child as ItemSlot
		assert_eq(item_slot.item, RunState.player.item_in_slot(item_slot.slot))


func test_new_run_has_the_focus() -> void:
	var run_end: RunEnd = _show_run_end(4, false)

	assert_true((run_end.get_node("%NewRunButton") as Button).has_focus())


# The scene change itself would replace the running GUT scene, so only its targets are checked.
func test_scene_paths_point_to_existing_scenes() -> void:
	assert_true(ResourceLoader.exists(MapScreen.MAP_SCENE_PATH, "PackedScene"))
	assert_true(ResourceLoader.exists(RunEnd.MAIN_MENU_SCENE_PATH, "PackedScene"))
