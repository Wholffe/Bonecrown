extends GutTest
## Content rules of the class skill pools and the level gates of the skills in them.

const DATA_ROOT: String = "res://scripts/data"
const RECKLESS_SWINGS: SkillData = preload("res://scripts/data/skills/reckless_swings.tres")
const GUARDED_STANCE: SkillData = preload("res://scripts/data/skills/guarded_stance.tres")
const ADRENALINE: SkillData = preload("res://scripts/data/skills/adrenaline.tres")
const FOCUS: SkillData = preload("res://scripts/data/skills/focus.tres")
## Skills with a drawback or a condition are offered from this level on (DECISIONS 2026-10-20).
const DRAWBACK_MIN_LEVEL: int = 4
## Focus is offered from this level on (DECISIONS 2026-10-20).
const FOCUS_MIN_LEVEL: int = 3

var _classes: Array[ClassData] = []


func before_all() -> void:
	for path: String in _find_resource_paths(DATA_ROOT):
		var class_data: ClassData = load(path) as ClassData
		if class_data != null:
			_classes.append(class_data)


func _find_resource_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tres"):
			paths.append(directory.path_join(file_name))
	for subdirectory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_find_resource_paths(directory.path_join(subdirectory)))
	return paths


# Mirrors Character._stat_modifier: only StatModifierEffect counts on passive skills.
func _has_passive_skill_rule(effect: EffectData) -> bool:
	return effect is StatModifierEffect


# Mirrors Combat._apply_effect: the effect types Combat can apply when an active skill is used.
func _has_active_skill_rule(effect: EffectData) -> bool:
	return effect is HealEffect or effect is AdvantageEffect


func _has_rule_for_every_effect(skill: SkillData) -> bool:
	for effect: EffectData in skill.effects:
		match skill.activation:
			SkillData.Activation.PASSIVE:
				if not _has_passive_skill_rule(effect):
					return false
			SkillData.Activation.ACTIVE:
				if not _has_active_skill_rule(effect):
					return false
			_:
				return false
	return true


func _has_drawback_or_condition(skill: SkillData) -> bool:
	for effect: EffectData in skill.effects:
		if effect is ConditionalModifierEffect:
			return true
		var modifier: StatModifierEffect = effect as StatModifierEffect
		if modifier != null and modifier.amount < 0:
			return true
	return false


func _ids(skills: Array[SkillData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for skill: SkillData in skills:
		ids.append(skill.id)
	return ids


func test_classes_exist() -> void:
	assert_gt(_classes.size(), 0, "No classes found under %s" % DATA_ROOT)


func test_classes_have_a_skill_pool_without_empty_slots() -> void:
	for class_data: ClassData in _classes:
		assert_gt(class_data.skill_pool.size(), 0, "%s has no skill pool" % class_data.id)
		assert_does_not_have(class_data.skill_pool, null, "%s pool" % class_data.id)


func test_pool_skills_are_passive_or_active_with_combat_rules() -> void:
	for class_data: ClassData in _classes:
		for skill: SkillData in class_data.skill_pool:
			assert_has(
				[SkillData.Activation.PASSIVE, SkillData.Activation.ACTIVE],
				skill.activation,
				"%s: %s activation" % [class_data.id, skill.id]
			)
			assert_true(
				_has_rule_for_every_effect(skill),
				"%s: %s has an effect without a rule" % [class_data.id, skill.id]
			)


func test_pool_skill_ids_are_unique() -> void:
	for class_data: ClassData in _classes:
		var seen_ids: Array[StringName] = []
		for skill_id: StringName in _ids(class_data.skill_pool):
			assert_does_not_have(seen_ids, skill_id, "%s: duplicate %s" % [class_data.id, skill_id])
			seen_ids.append(skill_id)


func test_pool_contains_no_starting_skill() -> void:
	for class_data: ClassData in _classes:
		var starting_ids: Array[StringName] = _ids(class_data.starting_skills)
		for skill_id: StringName in _ids(class_data.skill_pool):
			assert_does_not_have(
				starting_ids, skill_id, "%s: %s is a starting skill" % [class_data.id, skill_id]
			)


func test_pool_skills_have_a_description() -> void:
	for class_data: ClassData in _classes:
		for skill: SkillData in class_data.skill_pool:
			assert_ne(skill.description, "", "%s: %s description" % [class_data.id, skill.id])


func test_pool_skills_with_a_drawback_or_condition_unlock_at_level_4() -> void:
	for class_data: ClassData in _classes:
		for skill: SkillData in class_data.skill_pool:
			if _has_drawback_or_condition(skill):
				assert_gte(
					skill.min_level, DRAWBACK_MIN_LEVEL, "%s: %s" % [class_data.id, skill.id]
				)


func test_drawback_and_condition_skills_of_the_test_pool_unlock_at_level_4() -> void:
	assert_eq(RECKLESS_SWINGS.min_level, DRAWBACK_MIN_LEVEL, "Reckless Swings")
	assert_eq(GUARDED_STANCE.min_level, DRAWBACK_MIN_LEVEL, "Guarded Stance")
	assert_eq(ADRENALINE.min_level, DRAWBACK_MIN_LEVEL, "Adrenaline")


func test_focus_unlocks_at_level_3() -> void:
	assert_eq(FOCUS.min_level, FOCUS_MIN_LEVEL)
