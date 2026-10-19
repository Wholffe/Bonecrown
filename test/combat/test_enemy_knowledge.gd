extends GutTest

const GOBLIN_ID: StringName = &"goblin"
const ORC_ID: StringName = &"orc"
const NORMAL_CRIT_THRESHOLD: int = 20
const EXTENDED_CRIT_THRESHOLD: int = 19

var _knowledge: EnemyKnowledge


func before_each() -> void:
	_knowledge = EnemyKnowledge.new()


func _assert_armor_class_unknown(enemy_id: StringName) -> void:
	assert_eq(_knowledge.lowest_armor_class(enemy_id), EnemyKnowledge.UNKNOWN, "lowest AC")
	assert_eq(_knowledge.highest_armor_class(enemy_id), EnemyKnowledge.UNKNOWN, "highest AC")
	assert_false(_knowledge.is_armor_class_known(enemy_id))


func test_armor_class_and_attack_bonus_start_unknown() -> void:
	_assert_armor_class_unknown(GOBLIN_ID)
	assert_false(_knowledge.is_attack_bonus_known(GOBLIN_ID))
	assert_eq(_knowledge.attack_bonus(GOBLIN_ID), EnemyKnowledge.UNKNOWN)


func test_plain_hit_proves_armor_class_below_the_narrow_range() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(12, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_eq(_knowledge.highest_armor_class(GOBLIN_ID), 15, "12 + 5 = 17 hit, but not narrowly")
	assert_eq(_knowledge.lowest_armor_class(GOBLIN_ID), EnemyKnowledge.UNKNOWN)


func test_miss_proves_armor_class_above_total() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(6, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_eq(_knowledge.lowest_armor_class(GOBLIN_ID), 12, "6 + 5 = 11 missed")
	assert_eq(_knowledge.highest_armor_class(GOBLIN_ID), EnemyKnowledge.UNKNOWN)


func test_narrow_hit_proves_armor_class_within_margin_below_total() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(10, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_eq(_knowledge.lowest_armor_class(GOBLIN_ID), 14, "10 + 5 = 15 hit narrowly")
	assert_eq(_knowledge.highest_armor_class(GOBLIN_ID), 15)
	assert_false(_knowledge.is_armor_class_known(GOBLIN_ID))


func test_hit_and_miss_combine_to_range() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(12, 5, 14, NORMAL_CRIT_THRESHOLD))
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(6, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_eq(_knowledge.lowest_armor_class(GOBLIN_ID), 12)
	assert_eq(_knowledge.highest_armor_class(GOBLIN_ID), 15)
	assert_false(_knowledge.is_armor_class_known(GOBLIN_ID))


func test_range_closes_to_exact_armor_class() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(8, 5, 14, NORMAL_CRIT_THRESHOLD))
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(9, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_true(_knowledge.is_armor_class_known(GOBLIN_ID), "A miss at 13 and a hit at 14")
	assert_eq(_knowledge.lowest_armor_class(GOBLIN_ID), 14)
	assert_eq(_knowledge.highest_armor_class(GOBLIN_ID), 14)


func test_weaker_hit_does_not_loosen_upper_bound() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(11, 5, 14, NORMAL_CRIT_THRESHOLD))
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(14, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_eq(_knowledge.highest_armor_class(GOBLIN_ID), 14, "A plain hit at 19 after one at 16")


func test_weaker_miss_does_not_loosen_lower_bound() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(8, 5, 14, NORMAL_CRIT_THRESHOLD))
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(2, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_eq(_knowledge.lowest_armor_class(GOBLIN_ID), 14, "A miss at 7 after a miss at 13")


func test_natural_one_teaches_nothing() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(1, 5, 14, NORMAL_CRIT_THRESHOLD))

	_assert_armor_class_unknown(GOBLIN_ID)


func test_natural_twenty_teaches_nothing() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(20, 5, 14, NORMAL_CRIT_THRESHOLD))

	_assert_armor_class_unknown(GOBLIN_ID)


func test_crit_in_extended_range_teaches_nothing() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(19, 5, 14, EXTENDED_CRIT_THRESHOLD))

	_assert_armor_class_unknown(GOBLIN_ID)


func test_knowledge_is_kept_per_enemy_type() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(8, 5, 14, NORMAL_CRIT_THRESHOLD))
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(9, 5, 14, NORMAL_CRIT_THRESHOLD))
	_knowledge.record_enemy_attack(GOBLIN_ID, AttackRoll.new(10, 3, 14, NORMAL_CRIT_THRESHOLD))

	_assert_armor_class_unknown(ORC_ID)
	assert_false(_knowledge.is_attack_bonus_known(ORC_ID))


func test_enemy_attack_reveals_its_attack_bonus() -> void:
	_knowledge.record_enemy_attack(GOBLIN_ID, AttackRoll.new(10, 3, 14, NORMAL_CRIT_THRESHOLD))

	assert_true(_knowledge.is_attack_bonus_known(GOBLIN_ID))
	assert_eq(_knowledge.attack_bonus(GOBLIN_ID), 3)


func test_latest_enemy_attack_sets_the_known_attack_bonus() -> void:
	_knowledge.record_enemy_attack(GOBLIN_ID, AttackRoll.new(10, 3, 14, NORMAL_CRIT_THRESHOLD))
	_knowledge.record_enemy_attack(GOBLIN_ID, AttackRoll.new(10, 4, 14, NORMAL_CRIT_THRESHOLD))

	assert_eq(_knowledge.attack_bonus(GOBLIN_ID), 4, "The card never contradicts the last roll")


func test_enemy_natural_one_reveals_its_attack_bonus() -> void:
	_knowledge.record_enemy_attack(GOBLIN_ID, AttackRoll.new(1, 3, 14, NORMAL_CRIT_THRESHOLD))

	assert_true(_knowledge.is_attack_bonus_known(GOBLIN_ID), "The shown roll includes the bonus")
	assert_eq(_knowledge.attack_bonus(GOBLIN_ID), 3)


func test_enemy_attack_teaches_nothing_about_its_armor_class() -> void:
	_knowledge.record_enemy_attack(GOBLIN_ID, AttackRoll.new(10, 3, 14, NORMAL_CRIT_THRESHOLD))

	_assert_armor_class_unknown(GOBLIN_ID)


func test_player_attack_teaches_nothing_about_attack_bonus() -> void:
	_knowledge.record_player_attack(GOBLIN_ID, AttackRoll.new(12, 5, 14, NORMAL_CRIT_THRESHOLD))

	assert_false(_knowledge.is_attack_bonus_known(GOBLIN_ID))
