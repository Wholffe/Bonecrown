extends GutTest
## Skill offer rules of SkillOfferRoller: size, level gates, taken and stackable skills, caps.

const SEED: int = 777
const SEED_COUNT: int = 50
const POOL_SIZE: int = 9
const LEVEL: int = 3

# Not consts: Godot merges equal constant literals, so two empty typed const arrays in one script
# would share one instance and with it the element type of the first.
var _none_taken: Array[SkillData] = []
var _none_capped: Array[StatModifierEffect.Stat] = []


func _skill(id: StringName) -> SkillData:
	var skill: SkillData = SkillData.new()
	skill.id = id
	skill.activation = SkillData.Activation.PASSIVE
	return skill


func _modifier(stat: StatModifierEffect.Stat, amount: int) -> StatModifierEffect:
	var modifier: StatModifierEffect = StatModifierEffect.new()
	modifier.stat = stat
	modifier.amount = amount
	return modifier


func _skill_with(id: StringName, modifiers: Array[EffectData]) -> SkillData:
	var skill: SkillData = _skill(id)
	skill.effects = modifiers
	return skill


func _pool(size: int) -> Array[SkillData]:
	var pool: Array[SkillData] = []
	for index: int in size:
		pool.append(_skill(StringName("test_skill_%d" % index)))
	return pool


func _roll_offer(
	pool: Array[SkillData],
	level: int,
	taken: Array[SkillData],
	capped: Array[StatModifierEffect.Stat]
) -> Array[SkillData]:
	return SkillOfferRoller.new(DiceRoller.new(SEED)).roll_offer(pool, level, taken, capped)


func _ids(skills: Array[SkillData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for skill: SkillData in skills:
		ids.append(skill.id)
	return ids


func test_offer_has_three_different_skills() -> void:
	var pool: Array[SkillData] = _pool(POOL_SIZE)

	for seed_value: int in SEED_COUNT:
		var roller: SkillOfferRoller = SkillOfferRoller.new(DiceRoller.new(seed_value))
		var offer: Array[SkillData] = roller.roll_offer(pool, LEVEL, _none_taken, _none_capped)
		var ids: Array[StringName] = _ids(offer)
		assert_eq(ids.size(), SkillOfferRoller.OFFER_SIZE, "seed %d" % seed_value)
		for id: StringName in ids:
			assert_eq(ids.count(id), 1, "seed %d offers %s once" % [seed_value, id])


func test_offers_draw_from_the_whole_pool() -> void:
	var pool: Array[SkillData] = _pool(POOL_SIZE)
	var offered: Array[SkillData] = []

	for seed_value: int in SEED_COUNT:
		var roller: SkillOfferRoller = SkillOfferRoller.new(DiceRoller.new(seed_value))
		offered.append_array(roller.roll_offer(pool, LEVEL, _none_taken, _none_capped))

	for skill: SkillData in pool:
		assert_has(offered, skill, "%s over %d seeds" % [skill.id, SEED_COUNT])


func test_same_seed_gives_same_offer() -> void:
	var pool: Array[SkillData] = _pool(POOL_SIZE)

	var first: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, _none_capped)
	var second: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, _none_capped)

	assert_eq(first, second)


func test_skill_above_the_level_is_not_offered() -> void:
	var pool: Array[SkillData] = _pool(3)
	var later: SkillData = _skill(&"test_later")
	later.min_level = LEVEL + 1
	pool.append(later)

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, _none_capped)

	assert_eq(offer.size(), 3, "The three other skills are offered")
	assert_does_not_have(offer, later)


func test_skill_is_offered_from_its_min_level() -> void:
	var skill: SkillData = _skill(&"test_from_level")
	skill.min_level = LEVEL
	var pool: Array[SkillData] = [skill]

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, _none_capped)

	assert_eq(offer, pool)


func test_taken_skill_is_not_offered_again() -> void:
	var pool: Array[SkillData] = _pool(2)
	var taken: Array[SkillData] = [pool[0]]

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, taken, _none_capped)

	assert_eq(offer, [pool[1]] as Array[SkillData])


func test_taken_stackable_skill_is_offered_again() -> void:
	var skill: SkillData = _skill(&"test_stackable")
	skill.stackable = true
	var pool: Array[SkillData] = [skill]
	var taken: Array[SkillData] = [skill, skill]

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, taken, _none_capped)

	assert_eq(offer, pool)


func test_skill_raising_a_capped_attribute_is_not_offered() -> void:
	var strength: SkillData = _skill_with(
		&"test_strength", [_modifier(StatModifierEffect.Stat.STRENGTH, 2)]
	)
	var dexterity: SkillData = _skill_with(
		&"test_dexterity", [_modifier(StatModifierEffect.Stat.DEXTERITY, 2)]
	)
	var pool: Array[SkillData] = [strength, dexterity]
	var capped: Array[StatModifierEffect.Stat] = [StatModifierEffect.Stat.STRENGTH]

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, capped)

	assert_eq(offer, [dexterity] as Array[SkillData])


func test_any_raise_of_a_capped_attribute_drops_the_skill() -> void:
	var mixed: SkillData = _skill_with(
		&"test_mixed",
		[
			_modifier(StatModifierEffect.Stat.ATTACK, 1),
			_modifier(StatModifierEffect.Stat.LUCK, 2),
		]
	)
	var pool: Array[SkillData] = [mixed]
	var capped: Array[StatModifierEffect.Stat] = [StatModifierEffect.Stat.LUCK]

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, capped)

	assert_eq(offer, [] as Array[SkillData])


func test_skill_lowering_a_capped_attribute_is_offered() -> void:
	var reckless: SkillData = _skill_with(
		&"test_reckless",
		[
			_modifier(StatModifierEffect.Stat.MELEE_DAMAGE, 2),
			_modifier(StatModifierEffect.Stat.DEXTERITY, -2),
		]
	)
	var pool: Array[SkillData] = [reckless]
	var capped: Array[StatModifierEffect.Stat] = [StatModifierEffect.Stat.DEXTERITY]

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, capped)

	assert_eq(offer, pool, "Only raising a capped attribute is wasted")


func test_small_pool_offers_all_offerable_skills() -> void:
	var pool: Array[SkillData] = _pool(2)

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, _none_capped)

	assert_eq(offer.size(), 2)
	for skill: SkillData in pool:
		assert_has(offer, skill)


func test_offer_is_empty_when_no_skill_is_offerable() -> void:
	var pool: Array[SkillData] = _pool(1)

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, pool, _none_capped)

	assert_eq(offer, [] as Array[SkillData])


func test_skill_listed_twice_in_the_pool_is_offered_once() -> void:
	var pool: Array[SkillData] = _pool(2)
	pool.append(pool[0])

	var offer: Array[SkillData] = _roll_offer(pool, LEVEL, _none_taken, _none_capped)

	assert_eq(offer.size(), 2)
	assert_eq(offer.count(pool[0]), 1)
