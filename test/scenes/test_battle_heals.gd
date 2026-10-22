extends GutTest
## Battle scene: heals are titled with the skill the signal names, and a natural 20 drains with a
## log line, a pop-up and the hit point bar at the right step of the playback.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SECOND_WIND: SkillData = preload("res://scripts/data/skills/second_wind.tres")
const FOCUS: SkillData = preload("res://scripts/data/skills/focus.tres")
const SEED: int = 42
const SECOND_WIND_BUTTON: NodePath = ^"%SkillButtons/SecondWindButton"
const FOCUS_BUTTON: NodePath = ^"%SkillButtons/FocusButton"
## The warrior misses, Goblin 1 hits for 4 + 1 (9 HP left), Goblin 2 misses.
const WOUNDING_ROLLS: Array[int] = [2, 13, 4, 2]
## Round 1 as WOUNDING_ROLLS. Round 2: the warrior rolls a natural 20 for 3 + 2 + 4 = 9, which
## fells Goblin 1 and drains 4 (13 HP). Goblin 2 misses.
const WOUNDED_DRAIN_ROLLS: Array[int] = [2, 13, 4, 2, 20, 3, 2, 2]
## The warrior rolls a natural 20 at full health and fells Goblin 1, Goblin 2 misses.
const FULL_HEALTH_DRAIN_ROLLS: Array[int] = [20, 3, 2, 2]
## The warrior hits Goblin 1 with 12 + 5 = 17 for 3 + 4 (1 HP left). Goblin 1 rolls a natural 20
## for 3 + 3 + 1 = 7 and drains 3 (4 HP). Goblin 2 misses.
const GOBLIN_DRAIN_ROLLS: Array[int] = [12, 3, 20, 3, 3, 2]
## WOUNDING_ROLLS plus the d10 of Second Wind.
const SECOND_WIND_ROLLS: Array[int] = [2, 13, 4, 2, 3]
## Generous upper bound. A round with two animated attacks and a drain plays back in about 3 s.
const PLAYBACK_TIMEOUT: float = 15.0
const POSITION_TOLERANCE: float = 0.5


## Warrior: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP each.
func _start_battle(rolls: Array[int], learns_focus: bool = false) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	# Room 2 holds two goblins and picks them without a roll.
	RunState.advance_room()
	if learns_focus:
		RunState.player.learn_skill(FOCUS)
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)
	return battle


func _press(battle: Battle, button: Button) -> void:
	button.pressed.emit()
	await battle.wait_for_playback()


func _attack(battle: Battle) -> void:
	await _press(battle, battle.get_node("%AttackButton") as Button)


## Turns the animations on and starts an attack without waiting for its playback.
func _start_animated_attack(battle: Battle) -> void:
	battle.set_animations_enabled(true)
	(battle.get_node("%AttackButton") as Button).pressed.emit()


# Polls with a timeout, so a broken playback fails the test instead of hanging the suite.
func _finish_playback(battle: Battle) -> void:
	var is_idle: Callable = func() -> bool: return not battle.is_playing_back()
	var finished: bool = await wait_until(is_idle, PLAYBACK_TIMEOUT)
	assert_true(finished, "Playback must finish")


func _wait_for_log(battle: Battle, text: String) -> void:
	var is_logged: Callable = func() -> bool: return _log_text(battle).contains(text)
	var logged: bool = await wait_until(is_logged, PLAYBACK_TIMEOUT)
	assert_true(logged, "Precondition: '%s' is logged" % text)


func _player_card(battle: Battle) -> CombatantCard:
	return battle.get_node("%PlayerCard") as CombatantCard


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


func _hit_point_bar(card: CombatantCard) -> ProgressBar:
	return card.get_node("%HitPointBar") as ProgressBar


func _shown_hit_points(card: CombatantCard) -> int:
	return roundi(_hit_point_bar(card).value)


func _heal_title(battle: Battle) -> String:
	return (battle.get_node("%DiceDisplay").get_node("%TitleLabel") as Label).text


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func _drain_line(restored: int) -> String:
	return "Natural 20 – Crit + Drain: +%d HP" % restored


func _find_popup(battle: Battle, text: String) -> Label:
	for popup: Node in battle.get_node("%PopupLayer").get_children():
		if (popup as Label).text == text:
			return popup as Label
	return null


func test_second_wind_heal_is_titled_with_second_wind() -> void:
	var battle: Battle = _start_battle(SECOND_WIND_ROLLS)
	await _attack(battle)

	await _press(battle, battle.get_node(SECOND_WIND_BUTTON) as Button)

	assert_eq(_heal_title(battle), "%s: Second Wind" % RunState.player.display_name)
	assert_no_new_orphans()


func test_heal_is_titled_with_the_skill_the_signal_names() -> void:
	var battle: Battle = _start_battle([], true)
	var combat: Combat = battle._combat
	# A heal right after Focus was used: a label guessed from the last used skill would say Focus.
	combat.skill_used.connect(
		func(_user: Combatant, _skill: SkillData) -> void:
			combat.combatant_healed.emit(RunState.player, HealRoll.new([3], 10, 1), 0, SECOND_WIND),
		CONNECT_ONE_SHOT
	)

	await _press(battle, battle.get_node(FOCUS_BUTTON) as Button)

	assert_eq(_heal_title(battle), "%s: Second Wind" % RunState.player.display_name)
	assert_no_new_orphans()


func test_drain_is_logged_with_the_restored_hit_points_after_the_crit() -> void:
	var battle: Battle = _start_battle(WOUNDED_DRAIN_ROLLS)
	await _attack(battle)

	await _attack(battle)

	var log_text: String = _log_text(battle)
	var crit_index: int = log_text.find("critical hit!")
	var defeat_index: int = log_text.find("is defeated.")
	assert_gt(crit_index, -1, "Precondition: the crit is logged")
	assert_between(
		log_text.find(_drain_line(4)), crit_index, defeat_index, "Half of 9, rounded down"
	)
	assert_eq(_shown_hit_points(_player_card(battle)), 13, "9 HP + 4")
	assert_no_new_orphans()


func test_drain_at_full_health_restores_nothing() -> void:
	var battle: Battle = _start_battle(FULL_HEALTH_DRAIN_ROLLS)

	await _attack(battle)

	assert_string_contains(_log_text(battle), _drain_line(0))
	assert_no_new_orphans()


func test_enemy_drain_heals_its_card() -> void:
	var battle: Battle = _start_battle(GOBLIN_DRAIN_ROLLS)

	await _attack(battle)

	assert_string_contains(_log_text(battle), _drain_line(3), "Half of 7, rounded down")
	assert_eq(_shown_hit_points(_enemy_card(battle, 0)), 4, "1 HP + 3")
	assert_eq(_shown_hit_points(_player_card(battle)), 7, "14 HP - 7")
	assert_no_new_orphans()


func test_drain_fills_the_hit_point_bar_when_it_is_revealed() -> void:
	var battle: Battle = _start_battle(WOUNDED_DRAIN_ROLLS)
	var shown: Array[int] = []
	var drain_logged: Array[bool] = []
	await _attack(battle)
	assert_eq(_shown_hit_points(_player_card(battle)), 9, "Precondition: 14 HP - 5")
	_hit_point_bar(_player_card(battle)).value_changed.connect(
		func(value: float) -> void:
			shown.append(roundi(value))
			drain_logged.append(_log_text(battle).contains(_drain_line(4)))
	)

	_start_animated_attack(battle)
	await _finish_playback(battle)

	assert_eq(shown, [13] as Array[int], "One change, to the hit points after the drain")
	assert_eq(drain_logged, [true] as Array[bool], "The drain is revealed with the change")
	assert_no_new_orphans()


func test_drain_pops_up_the_restored_hit_points_over_the_attacker() -> void:
	var battle: Battle = _start_battle(WOUNDED_DRAIN_ROLLS)
	await _attack(battle)

	_start_animated_attack(battle)
	await _wait_for_log(battle, _drain_line(4))

	var popup: Label = _find_popup(battle, "+4")
	assert_not_null(popup, "The drain pops up like a heal")
	if popup != null:
		var player_x: float = _player_card(battle).get_global_rect().get_center().x
		var popup_x: float = popup.get_global_rect().get_center().x
		assert_almost_eq(popup_x, player_x, POSITION_TOLERANCE, "Centered on the warrior's card")
		var heal_color: Color = DiceDisplay.OUTCOME_COLORS[DiceDisplay.Outcome.HEAL]
		assert_eq(popup.label_settings.font_color, heal_color, "Green like other heals")
	await _finish_playback(battle)
	assert_no_new_orphans()
