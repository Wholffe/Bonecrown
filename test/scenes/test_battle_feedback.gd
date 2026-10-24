extends GutTest
## Battle scene feedback: pop-ups over the cards, the figures' lunge and knockback, the crit shake
## with and without animations, and the combat log that opens on demand.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42
const SECOND_WIND_BUTTON: NodePath = ^"%SkillButtons/SecondWindButton"
## The warrior hits Goblin 1 for 3 + 4 (1 HP left), Goblin 1 hits for 4 + 1, Goblin 2 for 2 + 1.
const ROUND_ROLLS: Array[int] = [17, 3, 13, 4, 13, 2]
## The warrior crits Goblin 1 for 3 + 2 + 4 and fells it, Goblin 2 misses.
const CRIT_ROLLS: Array[int] = [20, 3, 2, 2]
## The warrior misses, Goblin 1 hits for 4 + 1 (9 HP left), Goblin 2 misses. The heal rolls a 3.
const WOUNDED_ROLLS: Array[int] = [2, 13, 4, 2, 3]
## Generous upper bound. A round with three animated attacks plays back in about 3.2 seconds.
const PLAYBACK_TIMEOUT: float = 15.0
const POSITION_TOLERANCE: float = 0.5
## A shake would have moved the layout within this time, because tweens start a frame later.
const SHAKE_WATCH_TIME: float = 0.1
## A lunge or knockback shows within this time after the attack's log line.
const MOTION_WATCH_TIME: float = 1.0


## Warrior: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP each.
func _start_battle(rolls: Array[int], animations_enabled: bool) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	# A room 2 fight node with two goblins, so the fight starts without a roll.
	RunState.enter_node(GoblinPairNode.create())
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(animations_enabled)
	add_child_autofree(battle)
	return battle


func _attack(battle: Battle) -> void:
	(battle.get_node("%AttackButton") as Button).pressed.emit()


# Polls with a timeout, so a broken playback fails the test instead of hanging the suite.
func _finish_playback(battle: Battle) -> void:
	var is_idle: Callable = func() -> bool: return not battle.is_playing_back()
	var finished: bool = await wait_until(is_idle, PLAYBACK_TIMEOUT)
	assert_true(finished, "Playback must finish")


func _wait_for_log(battle: Battle, text: String) -> void:
	var log_label: RichTextLabel = battle.get_node("%CombatLog") as RichTextLabel
	var is_logged: Callable = func() -> bool: return log_label.get_parsed_text().contains(text)
	var logged: bool = await wait_until(is_logged, PLAYBACK_TIMEOUT)
	assert_true(logged, "Precondition: '%s' is logged" % text)


func _popup_layer(battle: Battle) -> PopupLayer:
	return battle.get_node("%PopupLayer") as PopupLayer


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


func _attack_line(attacker: Combatant, defender: Combatant) -> String:
	return "%s attacks %s" % [attacker.display_name, defender.display_name]


func _assert_popup_over(popup: Label, card: Control) -> void:
	var popup_x: float = popup.get_global_rect().get_center().x
	var card_x: float = card.get_global_rect().get_center().x
	assert_almost_eq(popup_x, card_x, POSITION_TOLERANCE, "The pop-up is centered on the card")


func test_no_popups_without_animations() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS, false)

	_attack(battle)
	await battle.wait_for_playback()

	assert_eq(_popup_layer(battle).get_child_count(), 0)
	assert_no_new_orphans()


func test_crit_leaves_the_layout_in_place_without_animations() -> void:
	var battle: Battle = _start_battle(CRIT_ROLLS, false)
	var margin: Control = battle.get_node("%Margin") as Control
	var rest: Vector2 = margin.position
	var moves: Array[Vector2] = []
	margin.item_rect_changed.connect(func() -> void: moves.append(margin.position))

	_attack(battle)
	await battle.wait_for_playback()
	await wait_seconds(SHAKE_WATCH_TIME)

	assert_eq(moves, [] as Array[Vector2], "No shake without animations")
	assert_eq(margin.position, rest)
	assert_no_new_orphans()


func test_revealed_attack_pops_up_its_damage_over_the_defender() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS, true)
	var goblin_card: CombatantCard = _enemy_card(battle, 0)

	_attack(battle)
	await _wait_for_log(battle, _attack_line(RunState.player, goblin_card.combatant))

	assert_eq(_popup_layer(battle).get_child_count(), 1, "Only the revealed attack pops up")
	var popup: Label = _popup_layer(battle).get_child(0) as Label
	assert_eq(popup.text, "-7", "3 + 4 damage")
	_assert_popup_over(popup, goblin_card)
	battle.set_animations_enabled(false)
	await _finish_playback(battle)
	assert_no_new_orphans()


func test_crit_shakes_the_layout_and_returns_it_to_rest() -> void:
	var battle: Battle = _start_battle(CRIT_ROLLS, true)
	var margin: Control = battle.get_node("%Margin") as Control
	var rest: Vector2 = margin.position
	var moves: Array[Vector2] = []
	margin.item_rect_changed.connect(func() -> void: moves.append(margin.position))

	_attack(battle)
	await _finish_playback(battle)

	assert_gt(moves.size(), 1, "The layout shakes")
	assert_eq(margin.position, rest, "The layout is back at its exact rest position")
	assert_no_new_orphans()


func test_heal_pops_up_over_the_player() -> void:
	var battle: Battle = _start_battle(WOUNDED_ROLLS, false)
	_attack(battle)
	await battle.wait_for_playback()
	battle.set_animations_enabled(true)

	(battle.get_node(SECOND_WIND_BUTTON) as Button).pressed.emit()
	await _wait_for_log(battle, "%s heals" % RunState.player.display_name)

	assert_eq(_popup_layer(battle).get_child_count(), 1)
	var popup: Label = _popup_layer(battle).get_child(0) as Label
	assert_eq(popup.text, "+4", "3 + level 1")
	_assert_popup_over(popup, battle.get_node("%PlayerCard") as Control)
	await _finish_playback(battle)
	assert_no_new_orphans()


func test_revealed_hit_lunges_the_attacker_and_knocks_back_the_defender() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS, true)
	var player_figure: FigureView = (battle.get_node("%PlayerCard") as CombatantCard).figure()
	var goblin_card: CombatantCard = _enemy_card(battle, 0)

	_attack(battle)
	await _wait_for_log(battle, _attack_line(RunState.player, goblin_card.combatant))

	var lunges: Callable = func() -> bool: return player_figure.offset_from_rest().x > 0.0
	assert_true(await wait_until(lunges, MOTION_WATCH_TIME), "The warrior lunges right")
	var knocked_back: Callable = func() -> bool:
		return goblin_card.figure().offset_from_rest().x > 0.0
	assert_true(await wait_until(knocked_back, MOTION_WATCH_TIME), "The goblin is pushed right")
	battle.set_animations_enabled(false)
	await _finish_playback(battle)
	assert_no_new_orphans()


func test_log_starts_closed_with_its_last_line_and_opens_on_demand() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS, false)
	var log_label: RichTextLabel = battle.get_node("%CombatLog") as RichTextLabel
	var toggle: Button = battle.get_node("%LogToggleButton") as Button
	_attack(battle)
	await battle.wait_for_playback()

	assert_false(battle.is_log_expanded(), "The log starts closed")
	assert_false(log_label.visible)
	var lines: PackedStringArray = log_label.get_parsed_text().strip_edges().split("\n")
	assert_eq((battle.get_node("%LastLogLabel") as Label).text, lines[-1])
	toggle.button_pressed = true
	assert_true(log_label.visible, "The toggle opens the log")
	assert_eq(toggle.text, Battle.HIDE_LOG_TEXT)
	toggle.button_pressed = false
	assert_false(log_label.visible, "and closes it again")
	assert_no_new_orphans()


func test_opened_log_shows_its_latest_lines() -> void:
	var battle: Battle = _start_battle(ROUND_ROLLS, false)
	var log_label: RichTextLabel = battle.get_node("%CombatLog") as RichTextLabel
	_attack(battle)
	await battle.wait_for_playback()

	battle.set_log_expanded(true)
	await wait_physics_frames(2)

	var scroll_bar: VScrollBar = log_label.get_v_scroll_bar()
	assert_gt(
		scroll_bar.max_value, scroll_bar.page, "Precondition: the round fills more than the box"
	)
	assert_almost_eq(scroll_bar.value + scroll_bar.page, scroll_bar.max_value, 1.0)
	assert_no_new_orphans()
