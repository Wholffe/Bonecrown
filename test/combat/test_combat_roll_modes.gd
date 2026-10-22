extends GutTest
## Roll mode rules of Combat: Focus gives advantage, a natural 1 gives Off-Balance (disadvantage).

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const FOCUS: SkillData = preload("res://scripts/data/skills/focus.tres")

var _player: Character
var _goblin: Enemy
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_player.learn_skill(FOCUS)
	_goblin = Enemy.new(GOBLIN)


## Warrior: attack +5, AC 14, d8+4, 14 HP, 2 Momentum. Goblin: attack +3, AC 12, d6+1, 8 HP.
## Attack costs 2 Momentum, Focus 1, and the turn ends when nothing is affordable.
func _start_combat(rolls: Array[int]) -> Combat:
	_dice = FixedDice.new(rolls)
	var enemies: Array[Combatant] = [_goblin]
	var combat: Combat = Combat.new(_player, enemies, _dice, GAME_RULES)
	watch_signals(combat)
	combat.start()
	return combat


func _attack_roll(combat: Combat, index: int) -> AttackRoll:
	return get_signal_parameters(combat, "attack_resolved", index)[2]


func test_focus_gives_the_next_attack_advantage() -> void:
	var combat: Combat = _start_combat([3, 15, 1])
	_player.momentum = 4

	combat.use_skill(FOCUS)
	combat.player_attack(_goblin)

	var attack: AttackRoll = _attack_roll(combat, 0)
	assert_eq(attack.roll_mode, AttackRoll.RollMode.ADVANTAGE)
	assert_eq(attack.natural_roll, 15)
	assert_eq(attack.discarded_roll, 3)
	assert_eq(_dice.remaining_rolls(), 0, "Two d20 and the damage die")


func test_focus_is_previewed_until_the_attack() -> void:
	var combat: Combat = _start_combat([3, 15, 1])
	_player.momentum = 4

	combat.use_skill(FOCUS)

	assert_eq(combat.next_roll_mode(_player), AttackRoll.RollMode.ADVANTAGE)
	combat.player_attack(_goblin)
	assert_eq(combat.next_roll_mode(_player), AttackRoll.RollMode.NORMAL)


func test_focus_lasts_for_one_attack() -> void:
	var combat: Combat = _start_combat([3, 15, 1, 10, 1])
	# More than the cap, so Focus and two attacks fit into one turn.
	_player.momentum = 5
	combat.use_skill(FOCUS)
	combat.player_attack(_goblin)

	combat.player_attack(_goblin)

	assert_eq(_attack_roll(combat, 1).roll_mode, AttackRoll.RollMode.NORMAL)
	assert_eq(_dice.remaining_rolls(), 0)


func test_natural_one_gives_the_next_attack_disadvantage() -> void:
	var combat: Combat = _start_combat([1, 2, 18, 9, 1])
	combat.player_attack(_goblin)

	combat.player_attack(_goblin)

	var attack: AttackRoll = _attack_roll(combat, 2)
	assert_eq(attack.roll_mode, AttackRoll.RollMode.DISADVANTAGE)
	assert_eq(attack.natural_roll, 9)
	assert_eq(attack.discarded_roll, 18)
	assert_eq(_dice.remaining_rolls(), 0)


func test_off_balance_lasts_for_one_attack() -> void:
	var combat: Combat = _start_combat([1, 2, 18, 9, 1, 2, 10, 1])
	combat.player_attack(_goblin)
	combat.player_attack(_goblin)
	combat.end_turn()

	combat.player_attack(_goblin)

	assert_eq(_attack_roll(combat, 4).roll_mode, AttackRoll.RollMode.NORMAL)
	assert_eq(_dice.remaining_rolls(), 0)


func test_natural_one_puts_enemies_off_balance_too() -> void:
	var combat: Combat = _start_combat([5, 1, 5, 15, 3])
	combat.player_attack(_goblin)
	combat.player_attack(_goblin)

	combat.end_turn()

	var goblin_attack: AttackRoll = _attack_roll(combat, 3)
	assert_eq(goblin_attack.roll_mode, AttackRoll.RollMode.DISADVANTAGE)
	assert_eq(goblin_attack.natural_roll, 3)
	assert_eq(_player.hit_points, _player.max_hit_points, "3 + 3 = 6 misses AC 14")


func test_off_balance_of_one_combatant_does_not_touch_the_other() -> void:
	var combat: Combat = _start_combat([1, 2])

	combat.player_attack(_goblin)

	assert_eq(combat.next_roll_mode(_player), AttackRoll.RollMode.DISADVANTAGE)
	assert_eq(combat.next_roll_mode(_goblin), AttackRoll.RollMode.NORMAL)


func test_focus_and_off_balance_cancel_out() -> void:
	var combat: Combat = _start_combat([1, 2, 12, 1, 2])
	combat.player_attack(_goblin)

	combat.use_skill(FOCUS)
	combat.player_attack(_goblin)

	assert_eq(_attack_roll(combat, 2).roll_mode, AttackRoll.RollMode.NORMAL)
	assert_eq(_dice.remaining_rolls(), 0, "A cancelled roll mode rolls one d20")


func test_natural_one_on_the_discarded_d20_gives_no_off_balance() -> void:
	var combat: Combat = _start_combat([1, 15, 1])
	_player.momentum = 4

	combat.use_skill(FOCUS)
	combat.player_attack(_goblin)

	assert_eq(combat.next_roll_mode(_player), AttackRoll.RollMode.NORMAL)


func test_natural_one_with_disadvantage_keeps_the_player_off_balance() -> void:
	var combat: Combat = _start_combat([1, 2, 1, 9, 2])
	combat.player_attack(_goblin)

	combat.player_attack(_goblin)

	assert_true(_attack_roll(combat, 2).is_natural_one)
	assert_eq(combat.next_roll_mode(_player), AttackRoll.RollMode.DISADVANTAGE)


func test_off_balance_ends_with_the_fight() -> void:
	var first: Combat = _start_combat([1, 2])
	first.player_attack(_goblin)
	assert_eq(first.next_roll_mode(_player), AttackRoll.RollMode.DISADVANTAGE)

	var second: Combat = _start_combat([])

	assert_eq(second.next_roll_mode(_player), AttackRoll.RollMode.NORMAL)
