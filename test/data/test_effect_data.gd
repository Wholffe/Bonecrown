extends GutTest
## Content rules of the stat modifiers on all skills and items under scripts/data.

const DATA_ROOT: String = "res://scripts/data"
## Stats a ConditionalModifierEffect may change. Conditions read hit points, so a conditional
## attribute modifier (Constitution) could change max HP and with it its own condition.
const COMBAT_STATS: Array[StatModifierEffect.Stat] = [
	StatModifierEffect.Stat.ATTACK,
	StatModifierEffect.Stat.MELEE_DAMAGE,
	StatModifierEffect.Stat.ARMOR_CLASS,
	StatModifierEffect.Stat.DAMAGE_REDUCTION,
]

## Skills and items, the two resource types that carry effects.
var _effect_holders: Array[Resource] = []


func before_all() -> void:
	for path: String in _find_resource_paths(DATA_ROOT):
		var resource: Resource = load(path)
		if resource is SkillData or resource is ItemData:
			_effect_holders.append(resource)


func _find_resource_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tres"):
			paths.append(directory.path_join(file_name))
	for subdirectory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_find_resource_paths(directory.path_join(subdirectory)))
	return paths


func _effects_of(holder: Resource) -> Array[EffectData]:
	var skill: SkillData = holder as SkillData
	if skill != null:
		return skill.effects
	return (holder as ItemData).effects


func _holder_name(holder: Resource) -> String:
	return holder.resource_path.get_file()


func test_effect_holders_exist() -> void:
	assert_gt(_effect_holders.size(), 0, "No skills or items found under %s" % DATA_ROOT)


func test_stat_modifiers_have_stat_and_amount() -> void:
	for holder: Resource in _effect_holders:
		for effect: EffectData in _effects_of(holder):
			var modifier: StatModifierEffect = effect as StatModifierEffect
			if modifier != null:
				assert_ne(
					modifier.stat, StatModifierEffect.Stat.UNSET, "%s stat" % _holder_name(holder)
				)
				assert_ne(modifier.amount, 0, "%s modifier amount" % _holder_name(holder))


func test_conditional_modifiers_have_a_condition() -> void:
	for holder: Resource in _effect_holders:
		for effect: EffectData in _effects_of(holder):
			var conditional: ConditionalModifierEffect = effect as ConditionalModifierEffect
			if conditional != null:
				assert_ne(
					conditional.condition,
					ConditionalModifierEffect.Condition.UNSET,
					"%s condition" % _holder_name(holder)
				)


func test_conditional_modifiers_only_change_combat_stats() -> void:
	for holder: Resource in _effect_holders:
		for effect: EffectData in _effects_of(holder):
			var conditional: ConditionalModifierEffect = effect as ConditionalModifierEffect
			if conditional != null:
				assert_has(
					COMBAT_STATS,
					conditional.stat,
					(
						"%s: conditional %s is no combat stat"
						% [_holder_name(holder), StatModifierEffect.Stat.find_key(conditional.stat)]
					)
				)


func test_area_and_retaliate_effects_roll_real_dice() -> void:
	for holder: Resource in _effect_holders:
		for effect: EffectData in _effects_of(holder):
			var area: AreaDamageEffect = effect as AreaDamageEffect
			if area != null:
				assert_gt(area.die_count, 0, "%s die count" % _holder_name(holder))
				assert_gt(area.die_sides, 0, "%s die sides" % _holder_name(holder))
			var retaliate: RetaliateEffect = effect as RetaliateEffect
			if retaliate != null:
				assert_gt(retaliate.die_count, 0, "%s die count" % _holder_name(holder))
				assert_gt(retaliate.die_sides, 0, "%s die sides" % _holder_name(holder))


func test_attack_splash_sets_count_and_sides_together() -> void:
	for holder: Resource in _effect_holders:
		for effect: EffectData in _effects_of(holder):
			var attack: AttackEffect = effect as AttackEffect
			if attack != null:
				assert_eq(
					attack.splash_die_count > 0,
					attack.splash_die_sides > 0,
					"%s splash dice" % _holder_name(holder)
				)


func test_momentum_gain_effects_gain_momentum() -> void:
	for holder: Resource in _effect_holders:
		for effect: EffectData in _effects_of(holder):
			var gain: MomentumGainEffect = effect as MomentumGainEffect
			if gain != null:
				assert_gt(gain.amount, 0, "%s amount" % _holder_name(holder))
				assert_gte(gain.hit_point_cost, 0, "%s HP cost" % _holder_name(holder))
