extends GutTest
## Dice display without animations: outcome tier, text and color, one reveal signal per roll and
## the second d20 of advantage and disadvantage.

const DICE_DISPLAY_SCENE: PackedScene = preload("res://scenes/ui/dice_display.tscn")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const ATTACK_BONUS: int = 5
const ARMOR_CLASS: int = 12
const CRIT_THRESHOLD: int = 20
## What the player knew before the roll. It differs from the real AC 12 on purpose.
const ARMOR_CLASS_TEXT: String = "AC 11–13"
## Natural roll, outcome and outcome text. With +5 against AC 12, a total of 12 or 13 is narrow.
const ATTACK_CASES: Array = [
	[20, DiceDisplay.Outcome.CRITICAL_HIT, "CRITICAL HIT"],
	[15, DiceDisplay.Outcome.HIT, "HIT"],
	[9, DiceDisplay.Outcome.HIT, "HIT"],
	[8, DiceDisplay.Outcome.NARROW_HIT, "NARROW HIT"],
	[7, DiceDisplay.Outcome.NARROW_HIT, "NARROW HIT"],
	[6, DiceDisplay.Outcome.MISS, "MISS"],
	[1, DiceDisplay.Outcome.NATURAL_ONE, "NATURAL 1"],
]
const HEAL_TITLE: String = "Warrior: Second Wind"
## Roll mode, kept d20, discarded d20 and the tag.
const TWO_DICE_CASES: Array = [
	[AttackRoll.RollMode.ADVANTAGE, 15, 4, "Advantage"],
	[AttackRoll.RollMode.DISADVANTAGE, 4, 15, "Disadvantage"],
]
## Generous upper bound. An animated roll lands after DiceDisplay.ROLL_DURATION.
const LANDING_TIMEOUT: float = 5.0


func _create_display() -> DiceDisplay:
	var display: DiceDisplay = DICE_DISPLAY_SCENE.instantiate() as DiceDisplay
	display.animations_enabled = false
	add_child_autofree(display)
	return display


func _play_attack(
	display: DiceDisplay,
	natural_roll: int,
	mode: AttackRoll.RollMode = AttackRoll.RollMode.NORMAL,
	discarded_roll: int = 0
) -> void:
	var attack: AttackRoll = AttackRoll.new(
		natural_roll, ATTACK_BONUS, ARMOR_CLASS, CRIT_THRESHOLD, mode, discarded_roll
	)
	var damage: DamageRoll = DamageRoll.new([3], 4) if attack.is_hit else null
	await display.play_attack(
		Enemy.new(GOBLIN), Enemy.new(GOBLIN), attack, damage, ARMOR_CLASS_TEXT
	)


func _play_heal(display: DiceDisplay, restored: int) -> void:
	await display.play_heal(HEAL_TITLE, HealRoll.new([3], 10, 1), restored)


func _outcome_label(display: DiceDisplay) -> Label:
	return display.get_node("%OutcomeLabel") as Label


func _label_text(display: DiceDisplay, label_name: String) -> String:
	return (display.get_node("%" + label_name) as Label).text


func _discarded_die(display: DiceDisplay) -> Control:
	return display.get_node("%DiscardedDie") as Control


func _roll_mode_label(display: DiceDisplay) -> Label:
	return display.get_node("%RollModeLabel") as Label


func test_attack_reveal_emits_its_outcome(params: Array = use_parameters(ATTACK_CASES)) -> void:
	var display: DiceDisplay = _create_display()
	watch_signals(display)

	await _play_attack(display, params[0])

	assert_signal_emitted_with_parameters(display, "result_revealed", [params[1]])
	assert_no_new_orphans()


func test_attack_reveal_shows_its_outcome_text(
	params: Array = use_parameters(ATTACK_CASES)
) -> void:
	var display: DiceDisplay = _create_display()

	await _play_attack(display, params[0])

	assert_eq(_outcome_label(display).text, params[2], "natural %d" % params[0])
	assert_no_new_orphans()


func test_attack_reveal_colors_its_outcome_text(
	params: Array = use_parameters(ATTACK_CASES)
) -> void:
	var display: DiceDisplay = _create_display()

	await _play_attack(display, params[0])

	var color: Color = _outcome_label(display).get_theme_color("font_color")
	assert_eq(color, DiceDisplay.OUTCOME_COLORS[params[1]], "natural %d" % params[0])
	assert_no_new_orphans()


func test_attack_reveal_emits_once_per_roll() -> void:
	var display: DiceDisplay = _create_display()
	watch_signals(display)

	await _play_attack(display, 15)
	await _play_attack(display, 6)

	assert_signal_emit_count(display, "result_revealed", 2)
	assert_no_new_orphans()


func test_attack_reveal_shows_the_total_against_the_passed_armor_class_text() -> void:
	var display: DiceDisplay = _create_display()

	await _play_attack(display, 15)

	assert_eq((display.get_node("%DetailLabel") as Label).text, "+5 = 20 vs AC 11–13")
	assert_no_new_orphans()


func test_heal_reveal_emits_heal() -> void:
	var display: DiceDisplay = _create_display()
	watch_signals(display)

	await _play_heal(display, 4)

	assert_signal_emitted_with_parameters(display, "result_revealed", [DiceDisplay.Outcome.HEAL])
	assert_no_new_orphans()


func test_heal_reveal_shows_the_restored_hit_points() -> void:
	var display: DiceDisplay = _create_display()

	await _play_heal(display, 2)

	assert_eq(_outcome_label(display).text, "HEALED 2", "Capped heals show what was restored")
	assert_no_new_orphans()


func test_every_outcome_has_its_own_text_color_and_die_tint() -> void:
	var outcomes: Array = DiceDisplay.Outcome.values()
	var texts: Dictionary[String, bool] = {}
	var colors: Dictionary[Color, bool] = {}
	var tints: Dictionary[Color, bool] = {}
	for outcome: DiceDisplay.Outcome in outcomes:
		texts[DiceDisplay.OUTCOME_TEXTS[outcome]] = true
		colors[DiceDisplay.OUTCOME_COLORS[outcome]] = true
		tints[DiceDisplay.DIE_TINTS[outcome]] = true

	assert_eq(texts.size(), outcomes.size(), "Texts")
	assert_eq(colors.size(), outcomes.size(), "Outcome colors")
	assert_eq(tints.size(), outcomes.size(), "Die tints")


func test_only_a_crit_pops_the_die_the_most() -> void:
	var crit_scale: float = DiceDisplay.REVEAL_SCALES[DiceDisplay.Outcome.CRITICAL_HIT]
	for outcome: DiceDisplay.Outcome in DiceDisplay.Outcome.values():
		if outcome != DiceDisplay.Outcome.CRITICAL_HIT:
			assert_lt(DiceDisplay.REVEAL_SCALES[outcome], crit_scale, "outcome %d" % outcome)


func test_misses_sag_the_die() -> void:
	assert_lt(DiceDisplay.SETTLED_SCALES[DiceDisplay.Outcome.MISS], 1.0, "Miss")
	assert_lt(
		DiceDisplay.SETTLED_SCALES[DiceDisplay.Outcome.NATURAL_ONE],
		DiceDisplay.SETTLED_SCALES[DiceDisplay.Outcome.MISS],
		"A natural 1 sags more than a miss"
	)


func test_roll_slows_down_and_lasts_the_roll_duration() -> void:
	var display: DiceDisplay = _create_display()

	var durations: Array[float] = display._roll_step_durations

	var total: float = 0.0
	for index: int in durations.size():
		total += durations[index]
		if index > 0:
			assert_gt(durations[index], durations[index - 1], "step %d" % index)
	assert_almost_eq(total, DiceDisplay.ROLL_DURATION, 0.001)
	assert_no_new_orphans()


func test_two_dice_roll_shows_the_discarded_die_dimmed_next_to_the_kept_one(
	params: Array = use_parameters(TWO_DICE_CASES)
) -> void:
	var display: DiceDisplay = _create_display()

	await _play_attack(display, params[1], params[0], params[2])

	assert_eq(_label_text(display, "DieLabel"), str(params[1]), "The kept die")
	assert_true(_discarded_die(display).visible, "The discarded die is shown")
	assert_eq(_label_text(display, "DiscardedDieLabel"), str(params[2]), "The discarded die")
	assert_eq(_discarded_die(display).modulate, DiceDisplay.DISCARDED_DIE_MODULATE, "Dimmed")
	assert_no_new_orphans()


func test_two_dice_roll_shows_its_roll_mode_tag(
	params: Array = use_parameters(TWO_DICE_CASES)
) -> void:
	var display: DiceDisplay = _create_display()

	await _play_attack(display, params[1], params[0], params[2])

	var tag: Label = _roll_mode_label(display)
	assert_true(tag.visible, "The tag is shown")
	assert_eq(tag.text, params[3])
	assert_eq(tag.get_theme_color("font_color"), DiceDisplay.ROLL_MODE_COLORS[params[0]])
	assert_no_new_orphans()


func test_normal_roll_shows_one_die_and_no_tag() -> void:
	var display: DiceDisplay = _create_display()

	await _play_attack(display, 15)

	assert_false(_discarded_die(display).visible, "No second die")
	assert_false(_roll_mode_label(display).visible, "No tag")
	assert_no_new_orphans()


func test_normal_roll_after_advantage_hides_the_second_die_and_the_tag() -> void:
	var display: DiceDisplay = _create_display()
	await _play_attack(display, 15, AttackRoll.RollMode.ADVANTAGE, 4)

	await _play_attack(display, 9)

	assert_false(_discarded_die(display).visible, "No second die")
	assert_false(_roll_mode_label(display).visible, "No tag")
	assert_no_new_orphans()


func test_discarded_die_rolls_undimmed_until_both_dice_land() -> void:
	var display: DiceDisplay = _create_display()
	display.animations_enabled = true

	# Not awaited, so the dice can be looked at while they roll.
	_play_attack(display, 15, AttackRoll.RollMode.ADVANTAGE, 4)

	assert_true(_discarded_die(display).visible, "Both dice roll")
	assert_eq(_discarded_die(display).modulate, Color.WHITE, "Not dimmed while rolling")
	var has_landed: Callable = func() -> bool: return _outcome_label(display).text != ""
	assert_true(await wait_until(has_landed, LANDING_TIMEOUT), "Precondition: the dice land")
	assert_eq(_discarded_die(display).modulate, DiceDisplay.DISCARDED_DIE_MODULATE, "Dimmed")
	assert_no_new_orphans()
