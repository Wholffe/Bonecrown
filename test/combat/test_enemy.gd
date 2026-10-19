extends GutTest

const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")

var _goblin: Enemy


func before_each() -> void:
	_goblin = Enemy.new(GOBLIN)


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
