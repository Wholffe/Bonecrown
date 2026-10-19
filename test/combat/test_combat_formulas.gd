extends GutTest

const CRIT_THRESHOLD_CASES: Array = [[-1, 20], [0, 20], [1, 20], [2, 19], [3, 19]]


func test_melee_attack_bonus_adds_strength_and_proficiency() -> void:
	assert_eq(CombatFormulas.melee_attack_bonus(3, 2), 5)


func test_armor_class_adds_armor_base_and_dexterity() -> void:
	assert_eq(CombatFormulas.armor_class(13, 1), 14)


func test_crit_threshold(params: Array = use_parameters(CRIT_THRESHOLD_CASES)) -> void:
	assert_eq(CombatFormulas.crit_threshold(params[0]), params[1], "luck bonus %d" % params[0])
