extends GutTest
## Battle scene with animations: hit points per shown event, input lock and freeing mid-roll.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SECOND_WIND: SkillData = preload("res://scripts/data/skills/second_wind.tres")
const SEED: int = 42
const SECOND_WIND_BUTTON: NodePath = ^"%SkillButtons/SecondWindButton"
## The warrior hits Goblin 1 for 3 + 4 (1 HP left), Goblin 1 hits for 4 + 1, Goblin 2 for 2 + 1.
const ROUND_ROLLS: Array[int] = [17, 3, 13, 4, 13, 2]
## Generous upper bound. A round with three animated attacks plays back in about 3.3 seconds.
const PLAYBACK_TIMEOUT: float = 15.0
const FRAMES_BEFORE_FREE: int = 3

var _dice: FixedDice


## Warrior: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP each.
func _start_battle(rolls: Array[int]) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	# A room 2 fight node with two goblins, so the fight starts without a roll.
	RunState.enter_node(GoblinPairNode.create())
	_dice = FixedDice.new(rolls)
	RunState.dice = _dice
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	add_child_autofree(battle)
	return battle


# Polls with a timeout, so a broken playback fails the test instead of hanging the suite.
func _finish_playback(battle: Battle) -> void:
	var is_idle: Callable = func() -> bool: return not battle.is_playing_back()
	var finished: bool = await wait_until(is_idle, PLAYBACK_TIMEOUT)
	assert_true(finished, "Playback must finish")


# For tests that only look at the start of the playback, the rest is played back without delays.
func _fast_forward(battle: Battle) -> void:
	battle.set_animations_enabled(false)
	await _finish_playback(battle)


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


# GUT's output panel lies on top of the test scene and would catch a click pushed through the
# viewport, so the click goes straight to the card's input handler.
func _click(card: CombatantCard) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card._gui_input(click)


func _player_card(battle: Battle) -> CombatantCard:
	return battle.get_node("%PlayerCard") as CombatantCard


func _hit_point_bar(card: CombatantCard) -> ProgressBar:
	return card.get_node("%HitPointBar") as ProgressBar


func _shown_hit_points(card: CombatantCard) -> int:
	return roundi(_hit_point_bar(card).value)


func _attack_button(battle: Battle) -> Button:
	return battle.get_node("%AttackButton") as Button


func _second_wind_button(battle: Battle) -> Button:
	return battle.get_node(SECOND_WIND_BUTTON) as Button


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func _attack_line(attacker: Combatant, defender: Combatant) -> String:
	return "%s attacks %s" % [attacker.display_name, defender.display_name]


func _round_line_count(battle: Battle) -> int:
	var count: int = 0
	for line: String in _log_text(battle).split("\n"):
		if line.begins_with("Round "):
			count += 1
	return count


func test_cards_keep_their_hit_points_while_the_first_roll_animates() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	var goblin_card: CombatantCard = _enemy_card(battle, 0)

	_attack_button(battle).pressed.emit()

	assert_eq(goblin_card.combatant.hit_points, 1, "Precondition: the whole round is resolved")
	assert_true(battle.is_playing_back(), "Precondition: the player's attack still rolls")
	assert_eq(_shown_hit_points(goblin_card), goblin_card.combatant.max_hit_points)
	assert_eq(_shown_hit_points(_player_card(battle)), RunState.player.max_hit_points)
	await _fast_forward(battle)
	assert_no_new_orphans()


func test_enemy_card_changes_when_the_player_attack_is_revealed() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	var goblin_card: CombatantCard = _enemy_card(battle, 0)
	var attack_line: String = _attack_line(RunState.player, goblin_card.combatant)
	var shown: Array[int] = []
	var attack_logged: Array[bool] = []
	var player_hit_points: Array[int] = []
	_hit_point_bar(goblin_card).value_changed.connect(
		func(value: float) -> void:
			shown.append(roundi(value))
			attack_logged.append(_log_text(battle).contains(attack_line))
			player_hit_points.append(_shown_hit_points(_player_card(battle)))
	)

	_attack_button(battle).pressed.emit()
	await _finish_playback(battle)

	assert_eq(shown, [1] as Array[int], "One change, to the hit points after the hit")
	assert_eq(attack_logged, [true] as Array[bool], "The attack is revealed before the change")
	assert_eq(
		player_hit_points,
		[RunState.player.max_hit_points] as Array[int],
		"The goblin's later hit is not shown yet"
	)
	assert_no_new_orphans()


func test_player_card_changes_with_each_enemy_attack_when_it_is_revealed() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	var first_line: String = _attack_line(_enemy_card(battle, 0).combatant, RunState.player)
	var second_line: String = _attack_line(_enemy_card(battle, 1).combatant, RunState.player)
	var shown: Array[int] = []
	var first_logged: Array[bool] = []
	var second_logged: Array[bool] = []
	_hit_point_bar(_player_card(battle)).value_changed.connect(
		func(value: float) -> void:
			shown.append(roundi(value))
			first_logged.append(_log_text(battle).contains(first_line))
			second_logged.append(_log_text(battle).contains(second_line))
	)

	_attack_button(battle).pressed.emit()
	await _finish_playback(battle)

	assert_eq(shown, [9, 6] as Array[int], "14 HP minus 4 + 1, then minus 2 + 1")
	assert_eq(first_logged, [true, true] as Array[bool], "Goblin 1's hit is revealed first")
	assert_eq(second_logged, [false, true] as Array[bool], "Goblin 2's hit is shown on its own")
	assert_no_new_orphans()


func test_actions_are_locked_during_playback() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)

	_attack_button(battle).pressed.emit()

	assert_true(battle.is_playing_back(), "Precondition: the player's attack still rolls")
	assert_true(_attack_button(battle).disabled, "Attack")
	assert_true(_second_wind_button(battle).disabled, "Second Wind")
	assert_true((battle.get_node("%MainMenuButton") as Button).disabled, "Main Menu")
	assert_false(_enemy_card(battle, 0).is_selectable(), "Goblin 1")
	assert_false(_enemy_card(battle, 1).is_selectable(), "Goblin 2")
	await _fast_forward(battle)
	assert_no_new_orphans()


func test_actions_are_unlocked_after_playback() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	_attack_button(battle).pressed.emit()

	await _fast_forward(battle)

	assert_false(_attack_button(battle).disabled, "Attack")
	assert_false(_second_wind_button(battle).disabled, "Second Wind")
	assert_false((battle.get_node("%MainMenuButton") as Button).disabled, "Main Menu")
	assert_true(_enemy_card(battle, 0).is_selectable(), "Goblin 1")
	assert_true(_enemy_card(battle, 1).is_selectable(), "Goblin 2")
	assert_no_new_orphans()


func test_attack_press_during_playback_is_ignored() -> void:
	# The last four rolls would be a second round, if the extra press were accepted.
	var battle: Battle = _start_battle([17, 3, 13, 4, 2, 17, 3, 2, 2])
	_attack_button(battle).pressed.emit()

	_attack_button(battle).pressed.emit()
	await _fast_forward(battle)

	assert_eq(_dice.remaining_rolls(), 4, "No second round may be rolled")
	assert_eq(_round_line_count(battle), 2, "Only rounds 1 and 2 are logged")
	assert_eq(_enemy_card(battle, 0).combatant.hit_points, 1, "Goblin 1 is hit only once")
	assert_no_new_orphans()


func test_skill_press_during_playback_is_ignored() -> void:
	# The last roll would be the heal, if the extra press were accepted.
	var battle: Battle = _start_battle([17, 3, 13, 4, 2, 5])
	_attack_button(battle).pressed.emit()

	_second_wind_button(battle).pressed.emit()
	await _fast_forward(battle)

	assert_eq(_dice.remaining_rolls(), 1, "Second Wind may not roll")
	var skill_line: String = "%s uses %s" % [RunState.player.display_name, SECOND_WIND.display_name]
	assert_false(_log_text(battle).contains(skill_line), "Second Wind may not be logged")
	assert_false(_second_wind_button(battle).disabled, "Second Wind stays available")
	assert_no_new_orphans()


func test_card_click_during_playback_keeps_the_mark() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	_attack_button(battle).pressed.emit()

	_click(_enemy_card(battle, 1))
	await _fast_forward(battle)

	assert_true(_enemy_card(battle, 0).is_selected(), "Goblin 1 stays marked")
	assert_false(_enemy_card(battle, 1).is_selected())
	assert_no_new_orphans()


func test_freeing_the_battle_during_a_roll_is_clean() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	_attack_button(battle).pressed.emit()
	await wait_process_frames(FRAMES_BEFORE_FREE)
	assert_true(battle.is_playing_back(), "Precondition: the player's attack still rolls")

	battle.free()
	await wait_seconds(DiceDisplay.ROLL_DURATION + DiceDisplay.HOLD_DURATION)

	assert_freed(battle, "battle")
	assert_engine_error_count(0, "No engine error after freeing mid-roll")
	assert_no_new_orphans()


func test_freeing_the_battle_while_a_result_is_held_is_clean() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	var attack_line: String = _attack_line(RunState.player, _enemy_card(battle, 0).combatant)
	_attack_button(battle).pressed.emit()
	var is_revealed: Callable = func() -> bool: return _log_text(battle).contains(attack_line)
	var revealed: bool = await wait_until(is_revealed, PLAYBACK_TIMEOUT)
	assert_true(revealed, "Precondition: the player's attack is revealed")
	assert_true(battle.is_playing_back(), "Precondition: the playback still runs")

	battle.free()
	await wait_seconds(DiceDisplay.ROLL_DURATION + DiceDisplay.HOLD_DURATION)

	assert_freed(battle, "battle")
	assert_engine_error_count(0, "No engine error after freeing mid-hold")
	assert_no_new_orphans()


func test_battle_can_be_freed_right_after_wait_for_playback() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS)
	_attack_button(battle).pressed.emit()
	assert_true(battle.is_playing_back(), "Precondition: the playback animates")

	await battle.wait_for_playback()
	battle.free()

	assert_freed(battle, "battle")
	assert_engine_error_count(0, "No engine error when freeing after wait_for_playback()")
	assert_no_new_orphans()
