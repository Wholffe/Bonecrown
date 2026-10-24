extends GutTest

const DATA_ROOT: String = "res://scripts/data"

var _resources: Array[Resource] = []


func before_all() -> void:
	for path: String in _find_resource_paths(DATA_ROOT):
		var resource: Resource = load(path)
		assert_not_null(resource, "%s must load" % path)
		_resources.append(resource)


func _find_resource_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tres"):
			paths.append(directory.path_join(file_name))
	for subdirectory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_find_resource_paths(directory.path_join(subdirectory)))
	return paths


func _skills() -> Array[SkillData]:
	var skills: Array[SkillData] = []
	for resource: Resource in _resources:
		if resource is SkillData:
			skills.append(resource)
	return skills


# Mirrors Combat._apply_effect: the effect types Combat can apply when an active skill is used.
func _has_active_skill_rule(effect: EffectData) -> bool:
	return (
		effect is HealEffect
		or effect is AdvantageEffect
		or effect is AttackEffect
		or effect is AreaDamageEffect
		or effect is MomentumGainEffect
	)


# Mirrors Character._stat_modifier and Combat's counterattack: the effect types that work while a
# passive skill is owned.
func _has_passive_skill_rule(effect: EffectData) -> bool:
	return effect is StatModifierEffect or effect is RetaliateEffect


func _effect_name(effect: EffectData) -> String:
	if effect == null:
		return "<empty slot>"
	var script: Script = effect.get_script()
	return script.resource_path.get_file()


func test_data_files_exist() -> void:
	assert_gt(_resources.size(), 0, "No .tres files found under %s" % DATA_ROOT)


func test_ids_are_set_and_unique() -> void:
	var seen_ids: Array[StringName] = []
	for resource: Resource in _resources:
		if not "id" in resource:
			continue
		var id: StringName = resource.get("id")
		assert_ne(id, &"", "%s has no id" % resource.resource_path)
		assert_does_not_have(seen_ids, id, "Duplicate id %s" % id)
		seen_ids.append(id)


func test_classes_have_starting_equipment() -> void:
	for resource: Resource in _resources:
		if resource is ClassData:
			var class_data: ClassData = resource
			assert_not_null(class_data.starting_weapon, "%s needs a weapon" % class_data.id)
			assert_not_null(class_data.starting_armor, "%s needs armor" % class_data.id)


func test_weapons_have_valid_damage_dice() -> void:
	for resource: Resource in _resources:
		if resource is WeaponData:
			var weapon: WeaponData = resource
			assert_gt(weapon.damage_die_count, 0, "%s die count" % weapon.id)
			assert_gt(weapon.damage_die_sides, 0, "%s die sides" % weapon.id)


func test_enemies_have_valid_damage_dice_and_hit_points() -> void:
	for resource: Resource in _resources:
		if resource is EnemyData:
			var enemy: EnemyData = resource
			assert_gt(enemy.damage_die_count, 0, "%s die count" % enemy.id)
			assert_gt(enemy.damage_die_sides, 0, "%s die sides" % enemy.id)
			assert_gt(enemy.max_hit_points, 0, "%s hit points" % enemy.id)


# The figure stands at the bottom of its box, so every frame of its idle loop must be the same size.
func test_classes_and_enemies_have_figures_with_frames_of_one_size() -> void:
	for resource: Resource in _resources:
		var frames: Array[Texture2D] = []
		if resource is EnemyData:
			frames = (resource as EnemyData).figure_frames
			assert_gt((resource as EnemyData).figure_scale, 0.0, "%s scale" % resource.get("id"))
		elif resource is ClassData:
			frames = (resource as ClassData).figure_frames
		else:
			continue
		assert_false(frames.is_empty(), "%s has a figure" % resource.get("id"))
		for frame: Texture2D in frames:
			assert_not_null(frame, "%s has an empty frame" % resource.get("id"))
			if frame != null and not frames.is_empty() and frames[0] != null:
				assert_eq(
					frame.get_size(), frames[0].get_size(), "%s frame size" % resource.get("id")
				)


# The first intent is the fallback when the enemy has no Momentum, so it must cost nothing.
func test_enemies_have_affordable_intents_in_cost_order() -> void:
	for resource: Resource in _resources:
		if resource is EnemyData:
			var enemy: EnemyData = resource
			assert_false(enemy.intents.is_empty(), "%s has no intents" % enemy.id)
			assert_eq(enemy.intents[0].momentum_cost, 0, "%s first intent cost" % enemy.id)
			var last_cost: int = 0
			for intent: EnemyIntentData in enemy.intents:
				assert_ne(intent.display_name, "", "%s: %s display name" % [enemy.id, intent.id])
				assert_gt(intent.attack_count, 0, "%s: %s attacks" % [enemy.id, intent.id])
				assert_gte(intent.momentum_cost, last_cost, "%s: %s order" % [enemy.id, intent.id])
				assert_lte(
					intent.momentum_cost, enemy.momentum_cap, "%s: %s cost" % [enemy.id, intent.id]
				)
				last_cost = intent.momentum_cost


func test_classes_have_no_empty_starting_skill_slots() -> void:
	for resource: Resource in _resources:
		if resource is ClassData:
			var class_data: ClassData = resource
			assert_does_not_have(class_data.starting_skills, null, "%s skills" % class_data.id)


func test_skills_have_effects() -> void:
	for resource: Resource in _resources:
		if resource is SkillData:
			var skill: SkillData = resource
			assert_gt(skill.effects.size(), 0, "%s has no effects" % skill.id)
			assert_does_not_have(skill.effects, null, "%s has an empty effect slot" % skill.id)


func test_heal_effects_have_valid_dice() -> void:
	for resource: Resource in _resources:
		if resource is SkillData:
			for effect: EffectData in (resource as SkillData).effects:
				var heal: HealEffect = effect as HealEffect
				if heal != null:
					assert_gt(heal.die_count, 0, "%s heal die count" % resource.resource_path)
					assert_gt(heal.die_sides, 0, "%s heal die sides" % resource.resource_path)


func test_skills_have_display_name_and_activation() -> void:
	for skill: SkillData in _skills():
		assert_ne(skill.display_name, "", "%s has no display name" % skill.id)
		assert_ne(skill.activation, SkillData.Activation.UNSET, "%s has no activation" % skill.id)


# A free skill without a use limit could be used forever in one turn.
func test_active_skills_cost_momentum_or_have_a_use_limit() -> void:
	for skill: SkillData in _skills():
		if skill.activation != SkillData.Activation.ACTIVE:
			continue
		assert_gte(skill.momentum_cost, 0, "%s Momentum cost" % skill.id)
		assert_gte(skill.uses_per_fight, 0, "%s uses per fight" % skill.id)
		assert_gt(
			skill.momentum_cost + skill.uses_per_fight, 0, "%s is free and unlimited" % skill.id
		)


func test_passive_skills_contain_only_passive_effect_types() -> void:
	for skill: SkillData in _skills():
		if skill.activation != SkillData.Activation.PASSIVE:
			continue
		for effect: EffectData in skill.effects:
			assert_true(
				_has_passive_skill_rule(effect),
				"%s: %s has no rule for passive skills" % [skill.id, _effect_name(effect)]
			)


func test_active_skills_contain_only_active_effect_types() -> void:
	for skill: SkillData in _skills():
		if skill.activation != SkillData.Activation.ACTIVE:
			continue
		for effect: EffectData in skill.effects:
			assert_true(
				_has_active_skill_rule(effect),
				"%s: %s has no rule for active skills" % [skill.id, _effect_name(effect)]
			)


func test_enum_fields_default_to_unset() -> void:
	var skill: SkillData = SkillData.new()
	var modifier: StatModifierEffect = StatModifierEffect.new()
	var conditional: ConditionalModifierEffect = ConditionalModifierEffect.new()
	var talisman: TalismanData = TalismanData.new()

	assert_eq(skill.activation, SkillData.Activation.UNSET)
	assert_eq(modifier.stat, StatModifierEffect.Stat.UNSET)
	assert_eq(conditional.condition, ConditionalModifierEffect.Condition.UNSET)
	assert_eq(talisman.rarity, ItemData.Rarity.UNSET)
