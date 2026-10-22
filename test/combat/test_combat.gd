extends GutTest
## Attacks, turn flow and the end of a fight. Skill rules are in test_combat_skills.gd.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")

var _player: Character
var _goblin: Enemy
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_goblin = Enemy.new(GOBLIN)


## Warrior: attack +5, AC 14, d8+4, 14 HP. Goblin: attack +3, AC 12, d6+1, 8 HP.
func _start_combat(rolls: Array[int]) -> Combat:
	var enemies: Array[Combatant] = [_goblin]
	return _start_group_combat(rolls, enemies)


func _start_group_combat(rolls: Array[int], enemies: Array[Combatant]) -> Combat:
	_dice = FixedDice.new(rolls)
	var combat: Combat = Combat.new(_player, enemies, _dice, GAME_RULES)
	watch_signals(combat)
	combat.start()
	return combat


func test_start_begins_round_one() -> void:
	var combat: Combat = _start_combat([])

	assert_eq(combat.round_number, 1)
	assert_signal_emitted_with_parameters(combat, "round_started", [1])


func test_killing_last_enemy_wins_before_it_can_act() -> void:
	var combat: Combat = _start_combat([15, 4, 20])

	combat.player_attack(_goblin)

	assert_false(_goblin.is_alive(), "15 + 5 hits AC 12, 4 + 4 damage kills 8 HP")
	assert_true(combat.is_over)
	assert_signal_emitted_with_parameters(combat, "combatant_defeated", [_goblin])
	assert_signal_emitted_with_parameters(combat, "combat_ended", [true])
	assert_eq(_dice.remaining_rolls(), 1, "A defeated goblin must not attack")


func test_enemy_attacks_after_player_and_next_round_starts() -> void:
	var combat: Combat = _start_combat([2, 15, 4])

	combat.player_attack(_goblin)

	assert_eq(_player.hit_points, 9, "15 + 3 hits AC 14 for 4 + 1 damage")
	assert_eq(combat.round_number, 2)
	assert_false(combat.is_over)


func test_miss_reports_attack_without_damage() -> void:
	var combat: Combat = _start_combat([2, 15, 4])

	combat.player_attack(_goblin)

	var params: Array = get_signal_parameters(combat, "attack_resolved", 0)
	assert_eq(params[0], _player)
	assert_eq(params[1], _goblin)
	assert_false((params[2] as AttackRoll).is_hit)
	assert_null(params[3], "A miss has no damage roll")


func test_crit_rolls_double_damage_dice() -> void:
	var combat: Combat = _start_combat([20, 1, 1, 2])

	combat.player_attack(_goblin)

	assert_eq(_goblin.hit_points, 2, "Crit deals 1 + 1 + 4 = 6 damage")
	assert_eq(_dice.remaining_rolls(), 0)


func test_player_death_ends_fight_with_defeat() -> void:
	var combat: Combat = _start_combat([2, 20, 6, 6, 2, 15, 3])

	combat.player_attack(_goblin)
	combat.player_attack(_goblin)

	assert_eq(_player.hit_points, 0, "Crit 6 + 6 + 1 leaves 1 HP, then 3 + 1 kills")
	assert_true(combat.is_over)
	assert_signal_emitted_with_parameters(combat, "combat_ended", [false])
	assert_signal_emit_count(combat, "round_started", 2)


func test_every_living_enemy_attacks_after_the_player() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN])
	var combat: Combat = _start_group_combat([2, 15, 4, 15, 2], group)

	combat.player_attack(group[1])

	assert_eq(_player.hit_points, 6, "Both goblins hit: 4 + 1 and 2 + 1")
	assert_signal_emit_count(combat, "attack_resolved", 3)


func test_player_attack_hits_the_chosen_target() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN])
	var combat: Combat = _start_group_combat([15, 4, 2], group)

	combat.player_attack(group[1])

	assert_true(group[0].is_alive())
	assert_false(group[1].is_alive(), "15 + 5 hits AC 12, 4 + 4 damage kills 8 HP")
	assert_eq(combat.living_enemies(), [group[0]] as Array[Combatant])
	assert_false(combat.is_over)


func test_defeated_group_member_does_not_attack() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN])
	var combat: Combat = _start_group_combat([15, 4, 2], group)
	combat.player_attack(group[1])

	combat.end_turn()

	assert_eq(_dice.remaining_rolls(), 0, "Only the living goblin rolls its attack")
	assert_signal_emit_count(combat, "attack_resolved", 2, "Player attack plus one goblin")
