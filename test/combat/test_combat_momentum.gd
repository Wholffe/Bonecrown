extends GutTest
## Momentum in Combat: gains, costs, the cap, Block, End Turn and when a turn ends on its own.

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
## Momentum: 2 at the start, +2 per round, cap 4, Attack 2, Block 1, +1 per miss against the
## player and per kill.
func _start_combat(rolls: Array[int], enemies: Array[Combatant] = [_goblin]) -> Combat:
	_dice = FixedDice.new(rolls)
	var combat: Combat = Combat.new(_player, enemies, _dice, GAME_RULES)
	watch_signals(combat)
	combat.start()
	return combat


## Every [momentum, change] reported for the combatant, in order.
func _momentum_changes(combat: Combat, combatant: Combatant) -> Array[Array]:
	var changes: Array[Array] = []
	for index: int in get_signal_emit_count(combat, "momentum_changed"):
		var params: Array = get_signal_parameters(combat, "momentum_changed", index)
		if params[0] == combatant:
			changes.append([params[1], params[2]])
	return changes


func test_fight_starts_with_the_starting_momentum() -> void:
	_player.momentum = 3
	var combat: Combat = _start_combat([])

	assert_eq(_player.momentum, 2, "Momentum of an earlier fight does not carry over")
	assert_eq(_momentum_changes(combat, _player), [[2, 2]] as Array[Array])


func test_attack_spends_momentum_and_the_turn_ends_when_nothing_is_affordable() -> void:
	var combat: Combat = _start_combat([2, 15, 4])

	combat.player_attack(_goblin)

	assert_eq(combat.round_number, 2, "0 Momentum left, so the goblin acts and round 2 starts")
	assert_eq(_dice.remaining_rolls(), 0, "Player miss, goblin hit and damage")
	assert_eq(_player.momentum, 2, "0 left, then +2 for round 2")


func test_turn_goes_on_while_an_action_is_affordable() -> void:
	var combat: Combat = _start_combat([2, 2, 2])
	combat.player_attack(_goblin)
	assert_eq(_player.momentum, 3, "Precondition: 0 + 1 for the goblin's miss + 2 for round 2")

	combat.player_attack(_goblin)

	assert_eq(combat.round_number, 2, "1 Momentum left pays for Block, so the turn goes on")
	assert_eq(_dice.remaining_rolls(), 0, "The goblin has not attacked again")
	assert_true(combat.has_affordable_action())


func test_momentum_carries_over_up_to_the_cap() -> void:
	var combat: Combat = _start_combat([2, 2, 2])
	combat.player_attack(_goblin)

	combat.end_turn()

	assert_eq(combat.round_number, 3)
	assert_eq(_player.momentum, 4, "3 + 1 for the miss + 2 for round 3, capped at 4")


func test_missed_enemy_attack_gives_momentum() -> void:
	var combat: Combat = _start_combat([2, 2])

	combat.player_attack(_goblin)

	var expected: Array[Array] = [[2, 2], [0, -2], [1, 1], [3, 2]]
	assert_eq(_momentum_changes(combat, _player), expected, "Start, attack, miss, round 2")


func test_kill_gives_momentum() -> void:
	var group: Array[Combatant] = Enemy.create_group([GOBLIN, GOBLIN])
	var combat: Combat = _start_combat([15, 4], group)

	combat.player_attack(group[0])

	assert_false(group[0].is_alive(), "Precondition: 15 + 5 hits, 4 + 4 kills 8 HP")
	assert_eq(_player.momentum, 1, "0 after the attack, +1 for the kill")
	assert_eq(combat.round_number, 1, "Block is still affordable, so the turn goes on")


func test_block_gives_enemy_attacks_disadvantage_until_the_next_turn() -> void:
	var combat: Combat = _start_combat([15, 3])
	combat.player_block()
	assert_eq(combat.next_roll_mode(_goblin), AttackRoll.RollMode.DISADVANTAGE, "Preview")

	combat.end_turn()

	var attack: AttackRoll = get_signal_parameters(combat, "attack_resolved", 0)[2]
	assert_eq(attack.roll_mode, AttackRoll.RollMode.DISADVANTAGE)
	assert_eq(attack.natural_roll, 3, "The lower d20 counts")
	assert_false(combat.is_player_blocking(), "Block ends when the player's next turn starts")
	assert_eq(combat.next_roll_mode(_goblin), AttackRoll.RollMode.NORMAL)


func test_block_once_per_turn() -> void:
	var combat: Combat = _start_combat([])

	combat.player_block()

	assert_eq(_player.momentum, 1)
	assert_true(combat.is_player_blocking())
	assert_false(combat.can_block(), "Block lasts the whole round already")
	assert_signal_emitted_with_parameters(combat, "player_blocked", [_player])


func test_actions_without_enough_momentum_do_nothing() -> void:
	var combat: Combat = _start_combat([2, 2, 2])
	combat.player_block()
	combat.end_turn()
	_player.momentum = 1

	combat.player_attack(_goblin)

	assert_push_error_count(1, "Attack costs 2")
	assert_eq(_player.momentum, 1)
	assert_signal_emit_count(combat, "attack_resolved", 1, "Only the goblin's attack")


func test_end_turn_lets_enemies_act_and_keeps_momentum() -> void:
	var combat: Combat = _start_combat([2])

	combat.end_turn()

	assert_eq(combat.round_number, 2)
	assert_eq(_player.momentum, 4, "2 kept + 1 for the miss + 2 for round 2, capped at 4")
	assert_signal_emit_count(combat, "player_turn_ended", 1)
