extends GutTest
## The boss data: its phases are ordered, playable and summon plain enemies.

const BONE_KING: BossData = preload("res://scripts/data/enemies/bone_king.tres")


func test_phase_thresholds_fall_from_phase_to_phase() -> void:
	var above: int = BONE_KING.max_hit_points
	for phase: BossPhaseData in BONE_KING.phases:
		assert_between(phase.hit_points_at_most, 1, above - 1)
		above = phase.hit_points_at_most


func test_every_phase_is_announced_and_has_a_free_intent() -> void:
	assert_false(BONE_KING.phases.is_empty())
	for phase: BossPhaseData in BONE_KING.phases:
		assert_ne(phase.announcement, "")
		assert_false(phase.intents.is_empty())
		assert_eq(phase.intents[0].momentum_cost, 0, "The first intent of a phase costs nothing")


func test_phase_intents_are_ordered_by_cost_and_affordable() -> void:
	for phase: BossPhaseData in BONE_KING.phases:
		var cost: int = 0
		for intent: EnemyIntentData in phase.intents:
			assert_true(intent.momentum_cost >= cost, "%s is out of order" % intent.id)
			assert_true(intent.momentum_cost <= phase.momentum_cap, "%s is too dear" % intent.id)
			cost = intent.momentum_cost


func test_every_intent_does_something() -> void:
	var intents: Array[EnemyIntentData] = BONE_KING.intents.duplicate()
	for phase: BossPhaseData in BONE_KING.phases:
		intents.append_array(phase.intents)
	for intent: EnemyIntentData in intents:
		assert_true(
			intent.attack_count > 0 or intent.momentum_to_allies > 0, "%s is idle" % intent.id
		)


func test_summons_are_plain_enemies() -> void:
	var summon_count: int = 0
	for phase: BossPhaseData in BONE_KING.phases:
		for summon: EnemyData in phase.summons:
			assert_false(summon is BossData, "A summon has no phases of its own")
			assert_true(summon.max_hit_points > 0)
			summon_count += 1
	assert_true(summon_count > 0, "The brief's phase 2 summons a skeleton")
