extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")

var _player: Character
var _goblin: Enemy
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES.proficiency_bonus)
	_goblin = Enemy.new(GOBLIN)


## Warrior: attack +5, AC 14, d8+3. Goblin: attack +3, AC 12, d6+1, 8 HP.
func _start_combat(rolls: Array[int]) -> Combat:
	_dice = FixedDice.new(rolls)
	var enemies: Array[Combatant] = [_goblin]
	var combat: Combat = Combat.new(_player, enemies, _dice)
	watch_signals(combat)
	combat.start()
	return combat


func test_start_begins_round_one() -> void:
	var combat: Combat = _start_combat([])

	assert_eq(combat.round_number, 1)
	assert_signal_emitted_with_parameters(combat, "round_started", [1])


func test_killing_last_enemy_wins_before_it_can_act() -> void:
	var combat: Combat = _start_combat([15, 5, 20])

	combat.player_attack(_goblin)

	assert_false(_goblin.is_alive(), "15 + 5 hits AC 12, 5 + 3 damage kills 8 HP")
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

	assert_eq(_goblin.hit_points, 3, "Crit deals 1 + 1 + 3 = 5 damage")
	assert_eq(_dice.remaining_rolls(), 0)


func test_player_death_ends_fight_with_defeat() -> void:
	var combat: Combat = _start_combat([2, 20, 6, 6, 2, 15, 3])

	combat.player_attack(_goblin)
	combat.player_attack(_goblin)

	assert_eq(_player.hit_points, 0, "Crit 6 + 6 + 1 leaves 1 HP, then 3 + 1 kills")
	assert_true(combat.is_over)
	assert_signal_emitted_with_parameters(combat, "combat_ended", [false])
	assert_signal_emit_count(combat, "round_started", 2)
