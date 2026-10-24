extends GutTest
## Skill tree screen: the columns, node buttons, details with value changes and blockers, learning a
## node and the specialization that fades the other branches.

const SKILL_TREE_SCENE: PackedScene = preload("res://scenes/skill_tree/skill_tree.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const STRENGTH_TRAINING: SkillData = preload("res://scripts/data/skills/strength_training.tres")
const DRAGON_BREATH: SkillData = preload("res://scripts/data/skills/dragon_breath.tres")
const SEED: int = 7


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)


func _create(level: int) -> SkillTreeScreen:
	while RunState.player.level < level:
		RunState.player.level_up()
	var screen: SkillTreeScreen = SKILL_TREE_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	return screen


func _label_text(screen: SkillTreeScreen, node_name: String) -> String:
	return (screen.get_node("%" + node_name) as Label).text


func _button(screen: SkillTreeScreen, node_name: String) -> Button:
	return screen.get_node("%" + node_name) as Button


func _column(screen: SkillTreeScreen, branch_name: String) -> Control:
	return screen.get_node("%Columns").get_node(branch_name + "Column") as Control


func _select(screen: SkillTreeScreen, node_id: StringName) -> void:
	screen.node_button(node_id).pressed.emit()
	await wait_process_frames(1)


func _learn(screen: SkillTreeScreen, node_id: StringName) -> void:
	await _select(screen, node_id)
	_button(screen, "LearnButton").pressed.emit()
	await wait_process_frames(1)


func test_columns_show_the_trunk_and_every_specialization() -> void:
	var screen: SkillTreeScreen = _create(2)

	var names: Array[String] = []
	for column: Node in screen.get_node("%Columns").get_children():
		names.append(column.name)
	assert_eq(
		names,
		["TrainingColumn", "DragonfireColumn", "BerserkerColumn", "BulwarkColumn"] as Array[String]
	)


func test_first_learnable_node_is_selected_with_its_value_changes() -> void:
	var screen: SkillTreeScreen = _create(2)

	assert_eq(screen.selected_node().id, &"strength_training")
	assert_eq(_label_text(screen, "NodeNameLabel"), "Strength Training   ·   rank 0/2")
	assert_string_contains(_label_text(screen, "NodeDetailsLabel"), "Attack +5 → +6")
	assert_false(_button(screen, "LearnButton").disabled)


func test_learning_spends_the_point() -> void:
	var screen: SkillTreeScreen = _create(2)

	await _learn(screen, &"strength_training")

	assert_has(RunState.player.skills, STRENGTH_TRAINING)
	assert_eq(screen.node_button(&"strength_training").text, "Strength Training  1/2")
	assert_true(_button(screen, "LearnButton").disabled)
	assert_string_contains(_label_text(screen, "HintLabel"), "Skill points: 0")


func test_second_learn_press_without_a_point_learns_nothing() -> void:
	var screen: SkillTreeScreen = _create(2)
	await _learn(screen, &"strength_training")

	screen.learn_selected()

	assert_eq(RunState.skill_tree.rank_of(screen.selected_node()), 1)


func test_next_rank_shows_the_rank_it_replaces() -> void:
	var screen: SkillTreeScreen = _create(3)
	await _learn(screen, &"strength_training")

	var details: String = _label_text(screen, "NodeDetailsLabel")

	assert_eq(_label_text(screen, "NodeNameLabel"), "Strength Training II   ·   rank 1/2")
	assert_string_contains(details, "Now: +2 Strength.")
	assert_string_contains(details, "Attack +6 → +7")


func test_specializations_name_their_level_before_it() -> void:
	var screen: SkillTreeScreen = _create(2)

	await _select(screen, &"dragon_breath")

	assert_true(_button(screen, "LearnButton").disabled)
	assert_string_contains(_label_text(screen, "NodeDetailsLabel"), "Opens at level 3.")
	assert_string_contains(_label_text(screen, "HintLabel"), "Specializations open at level 3.")


func test_details_name_the_activation_and_a_missing_requirement() -> void:
	var screen: SkillTreeScreen = _create(3)

	await _select(screen, &"draconic_scales")

	var details: String = _label_text(screen, "NodeDetailsLabel")
	assert_true(details.begins_with("Passive."), details)
	assert_string_contains(details, "Needs Dragon Breath.")
	await _select(screen, &"dragon_breath")
	assert_true(_label_text(screen, "NodeDetailsLabel").begins_with("Active, 2 Momentum."))


func test_first_specialization_node_fades_the_other_branches() -> void:
	var screen: SkillTreeScreen = _create(4)

	await _learn(screen, &"dragon_breath")

	assert_has(RunState.player.skills, DRAGON_BREATH)
	assert_eq(_column(screen, "Dragonfire").modulate, Color.WHITE)
	assert_eq(_column(screen, "Training").modulate, Color.WHITE)
	assert_eq(_column(screen, "Berserker").modulate, SkillTreeScreen.CLOSED_BRANCH_MODULATE)
	assert_eq(_column(screen, "Bulwark").modulate, SkillTreeScreen.CLOSED_BRANCH_MODULATE)
	assert_string_contains(_label_text(screen, "HintLabel"), "Specialization: Dragonfire")


func test_closed_branch_names_the_chosen_specialization() -> void:
	var screen: SkillTreeScreen = _create(4)
	await _learn(screen, &"dragon_breath")

	await _select(screen, &"mighty_blow")

	assert_true(_button(screen, "LearnButton").disabled)
	assert_string_contains(_label_text(screen, "NodeDetailsLabel"), "Closed: you chose Dragonfire.")


func test_conditional_skill_shows_its_condition() -> void:
	var screen: SkillTreeScreen = _create(5)
	await _learn(screen, &"mighty_blow")

	await _select(screen, &"adrenaline")

	assert_string_contains(_label_text(screen, "NodeDetailsLabel"), "Damage +2")
	assert_string_contains(_label_text(screen, "NodeDetailsLabel"), "HP or less")


func test_continue_takes_focus_once_every_point_is_spent() -> void:
	var screen: SkillTreeScreen = _create(2)

	await _learn(screen, &"strength_training")

	assert_true(_button(screen, "ContinueButton").has_focus())


func test_character_button_toggles_the_sheet() -> void:
	var screen: SkillTreeScreen = _create(2)

	_button(screen, "CharacterButton").pressed.emit()
	await wait_process_frames(1)

	assert_true((screen.get_node("%CharacterSheet") as CharacterSheet).visible)
