extends GutTest
## Damage rules of Combat: damage reduction, crit resistance and the Drain of a natural 20.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const IRON_SKIN: SkillData = preload("res://scripts/data/skills/iron_skin.tres")
const FOUR_LEAF_CLOVER: TalismanData = preload("res://scripts/data/items/four_leaf_clover.tres")

var _player: Character
var _goblin: Enemy
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_goblin = Enemy.new(GOBLIN)


## Warrior: attack +5, AC 14, d8+4, 14 HP. Goblin: attack +3, AC 12, d6+1, 8 HP.
func _start_combat(rolls: Array[int]) -> Combat:
	_dice = FixedDice.new(rolls)
	var enemies: Array[Combatant] = [_goblin]
	var combat: Combat = Combat.new(_player, enemies, _dice, GAME_RULES)
	watch_signals(combat)
	combat.start()
	return combat


## Records the order of the attack, drain and defeat signals.
func _record_signal_order(combat: Combat) -> Array[StringName]:
	var order: Array[StringName] = []
	combat.attack_resolved.connect(
		func(_a: Combatant, _d: Combatant, _attack: AttackRoll, _damage: DamageRoll) -> void:
			order.append(&"attack_resolved")
	)
	combat.attacker_drained.connect(
		func(_attacker: Combatant, _drained: int, _restored: int) -> void:
			order.append(&"attacker_drained")
	)
	combat.combatant_defeated.connect(
		func(_combatant: Combatant) -> void: order.append(&"combatant_defeated")
	)
	return order


func test_damage_reduction_lowers_damage_taken() -> void:
	_player.learn_skill(IRON_SKIN)
	var combat: Combat = _start_combat([2, 15, 4])

	combat.player_attack(_goblin)

	assert_eq(_player.hit_points, 10, "4 + 1 = 5, less 1 from Iron Skin")
	var damage: DamageRoll = get_signal_parameters(combat, "attack_resolved", 1)[3]
	assert_eq(damage.damage_reduction, 1)


func test_damage_reduction_leaves_at_least_one_damage() -> void:
	_player.learn_skill(IRON_SKIN)
	var weak_goblin: EnemyData = GOBLIN.duplicate()
	weak_goblin.damage_bonus = 0
	_goblin = Enemy.new(weak_goblin)
	var combat: Combat = _start_combat([2, 15, 1])

	combat.player_attack(_goblin)

	assert_eq(_player.hit_points, 13, "1 damage, less 1, is still 1")


func test_natural_twenty_drains_half_the_damage_rolled() -> void:
	_player.take_damage(10)
	var combat: Combat = _start_combat([20, 3, 2])

	combat.player_attack(_goblin)

	assert_signal_emitted_with_parameters(combat, "attacker_drained", [_player, 4, 4])
	assert_eq(_player.hit_points, 8, "4 HP + half of 3 + 2 + 4 = 9, rounded down")


func test_drain_counts_overkill() -> void:
	_goblin.take_damage(7)
	_player.take_damage(10)
	var combat: Combat = _start_combat([20, 3, 2])

	combat.player_attack(_goblin)

	assert_signal_emitted_with_parameters(combat, "attacker_drained", [_player, 4, 4])


func test_drain_stops_at_max_hit_points() -> void:
	_player.take_damage(1)
	var combat: Combat = _start_combat([20, 3, 2])

	combat.player_attack(_goblin)

	assert_signal_emitted_with_parameters(combat, "attacker_drained", [_player, 4, 1])
	assert_eq(_player.hit_points, _player.max_hit_points)


func test_crit_in_the_extended_range_does_not_drain() -> void:
	_player.equip(FOUR_LEAF_CLOVER)
	_player.take_damage(10)
	var combat: Combat = _start_combat([19, 3, 2])

	combat.player_attack(_goblin)

	assert_true(get_signal_parameters(combat, "attack_resolved", 0)[2].is_crit)
	assert_signal_not_emitted(combat, "attacker_drained")
	assert_eq(_player.hit_points, 4)


func test_enemy_natural_twenty_drains_the_enemy() -> void:
	_goblin.take_damage(5)
	var combat: Combat = _start_combat([2, 20, 3, 4])

	combat.player_attack(_goblin)

	assert_eq(_player.hit_points, 6, "Crit 3 + 4 + 1 = 8")
	assert_signal_emitted_with_parameters(combat, "attacker_drained", [_goblin, 4, 4])
	assert_eq(_goblin.hit_points, 7)


func test_drain_ignores_the_defenders_damage_reduction() -> void:
	_player.learn_skill(IRON_SKIN)
	_goblin.take_damage(5)
	var combat: Combat = _start_combat([2, 20, 3, 4])

	combat.player_attack(_goblin)

	assert_eq(_player.hit_points, 7, "8 rolled, less 1 from Iron Skin")
	assert_signal_emitted_with_parameters(combat, "attacker_drained", [_goblin, 4, 4])


func test_drain_comes_between_the_attack_and_the_defeat() -> void:
	var combat: Combat = _start_combat([20, 3, 2])
	var order: Array[StringName] = _record_signal_order(combat)

	combat.player_attack(_goblin)

	assert_eq(
		order, [&"attack_resolved", &"attacker_drained", &"combatant_defeated"] as Array[StringName]
	)


func test_plain_hit_does_not_drain() -> void:
	var combat: Combat = _start_combat([15, 3, 2])

	combat.player_attack(_goblin)

	assert_signal_not_emitted(combat, "attacker_drained")


func test_crit_against_a_crit_resistant_enemy_rolls_the_dice_once() -> void:
	var data: EnemyData = GOBLIN.duplicate()
	data.crit_resistant = true
	_goblin = Enemy.new(data)
	var combat: Combat = _start_combat([20, 3, 2])

	combat.player_attack(_goblin)

	var damage: DamageRoll = get_signal_parameters(combat, "attack_resolved", 0)[3]
	assert_eq(damage.dice_results, [3] as Array[int], "One d8 instead of two")
	assert_eq(_goblin.hit_points, 1, "3 + 4 damage")
	assert_true(get_signal_parameters(combat, "attack_resolved", 0)[2].is_crit, "Still a crit")
