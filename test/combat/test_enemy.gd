extends GutTest

const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
## [hit point percent, max hit points] of a goblin with 8 hit points.
const HIT_POINT_PERCENT_CASES: Array = [[0, 8], [10, 9], [30, 10], [50, 12]]

var _goblin: Enemy


func before_each() -> void:
	_goblin = Enemy.new(GOBLIN)


func _enemy_data(id: StringName, display_name: String) -> EnemyData:
	var enemy_data: EnemyData = GOBLIN.duplicate()
	enemy_data.id = id
	enemy_data.display_name = display_name
	return enemy_data


func _display_names(group: Array[Combatant]) -> Array[String]:
	var names: Array[String] = []
	for enemy: Combatant in group:
		names.append(enemy.display_name)
	return names


func test_goblin_has_brief_values() -> void:
	assert_eq(_goblin.get_armor_class(), 12)
	assert_eq(_goblin.max_hit_points, 8)
	assert_eq(_goblin.hit_points, 8)
	assert_eq(_goblin.get_attack_bonus(), 3)
	assert_eq(_goblin.get_damage_die_count(), 1)
	assert_eq(_goblin.get_damage_die_sides(), 6)
	assert_eq(_goblin.get_damage_bonus(), 1)


func test_enemy_crits_only_on_natural_20() -> void:
	assert_eq(_goblin.get_crit_threshold(), 20)


func test_take_damage_lowers_hit_points() -> void:
	_goblin.take_damage(3)

	assert_eq(_goblin.hit_points, 5)
	assert_true(_goblin.is_alive())


func test_hit_points_stop_at_zero() -> void:
	_goblin.take_damage(50)

	assert_eq(_goblin.hit_points, 0)
	assert_false(_goblin.is_alive())


func test_damage_leaves_shared_data_untouched() -> void:
	_goblin.take_damage(5)

	assert_eq(GOBLIN.max_hit_points, 8)
	assert_eq(Enemy.new(GOBLIN).hit_points, 8, "A new goblin must start at full health")


func test_heal_restores_hit_points_up_to_maximum() -> void:
	_goblin.take_damage(5)

	var restored: int = _goblin.heal(10)

	assert_eq(_goblin.hit_points, 8)
	assert_eq(restored, 5, "Only the missing hit points count as restored")


func test_group_numbers_duplicate_enemies() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN])

	assert_eq(group.size(), 2)
	assert_eq(group[0].display_name, "Goblin 1")
	assert_eq(group[1].display_name, "Goblin 2")


func test_group_keeps_name_of_single_enemy() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN])

	assert_eq(group[0].display_name, "Goblin")


func test_group_members_take_damage_separately() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN])

	group[0].take_damage(3)

	assert_eq(group[0].hit_points, 5)
	assert_eq(group[1].hit_points, 8, "Damage to one goblin must not touch the other")


func test_group_numbers_only_the_duplicates_in_a_mixed_group() -> void:
	var orc: EnemyData = _enemy_data(&"test_orc", "Orc")

	var group: Array[Combatant] = Enemy.create_group([GOBLIN, orc, GOBLIN])

	assert_eq(_display_names(group), ["Goblin 1", "Orc", "Goblin 2"] as Array[String])


func test_group_numbers_different_enemies_that_share_a_display_name() -> void:
	var other_goblin: EnemyData = _enemy_data(&"test_goblin_variant", GOBLIN.display_name)

	var group: Array[Combatant] = Enemy.create_group([GOBLIN, other_goblin])

	assert_eq(_display_names(group), ["Goblin 1", "Goblin 2"] as Array[String])


func test_group_adds_the_attack_modifier_to_every_enemy() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN], 2)

	assert_eq(group[0].get_attack_bonus(), 5)
	assert_eq(group[1].get_attack_bonus(), 5)


func test_group_raises_hit_points_by_percent_and_rounds(
	params: Array = use_parameters(HIT_POINT_PERCENT_CASES)
) -> void:
	var goblin: Combatant = Enemy.create_group([GOBLIN], 0, params[0])[0]

	assert_eq(goblin.max_hit_points, params[1], "+%d%%" % params[0])
	assert_eq(goblin.hit_points, params[1], "+%d%% starts at full health" % params[0])


func test_group_puts_the_name_prefix_before_the_number() -> void:
	var pair: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN], 0, 0, "Elite ")
	var single: Array[Combatant] = Enemy.create_group([GOBLIN], 0, 0, "Elite ")

	assert_eq(_display_names(pair), ["Elite Goblin 1", "Elite Goblin 2"] as Array[String])
	assert_eq(_display_names(single), ["Elite Goblin"] as Array[String])


func test_group_modifiers_leave_shared_data_untouched() -> void:
	Enemy.create_group([GOBLIN], 2, 50, "Elite ")

	assert_eq(GOBLIN.display_name, "Goblin")
	assert_eq(GOBLIN.attack_bonus, 3)
	assert_eq(GOBLIN.max_hit_points, 8)
