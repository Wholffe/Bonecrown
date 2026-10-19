class_name DiceDisplay
extends PanelContainer
## Shows the current roll with a short animation: who rolls, the die, the total and the outcome.

## Emitted once per revealed result, also without animations, so feedback such as sound can follow.
signal result_revealed(outcome: Outcome)

enum Outcome { CRITICAL_HIT, HIT, NARROW_HIT, MISS, NATURAL_ONE, HEAL }

## Time from the first rolling face until the die lands.
const ROLL_DURATION: float = 0.65
const ROLL_STEPS: int = 9
## The last face stays this many times longer than the first, so the die slows down before it lands.
const ROLL_SLOWDOWN: float = 4.0
## An ease() curve above 1: the faces slow down little at first and most just before the landing.
const ROLL_EASE_CURVE: float = 2.0
## Hit-stop: the landed die stays still for a moment before a crit is revealed.
const CRIT_FREEZE_DURATION: float = 0.1
const PUNCH_DURATION: float = 0.2
const HOLD_DURATION: float = 0.4
# Deterministic stand-in for random faces while rolling. It is coprime to 20, so a d20 shows all.
const ROLL_FACE_STEP: int = 7
const NEUTRAL_DIE_TINT: Color = Color.WHITE
const NEUTRAL_DIE_NUMBER_COLOR: Color = Color(0.1, 0.1, 0.1)
const OUTCOME_TEXTS: Dictionary[Outcome, String] = {
	Outcome.CRITICAL_HIT: "CRITICAL HIT",
	Outcome.HIT: "HIT",
	Outcome.NARROW_HIT: "NARROW HIT",
	Outcome.MISS: "MISS",
	Outcome.NATURAL_ONE: "NATURAL 1",
	Outcome.HEAL: "HEALED",
}
const OUTCOME_COLORS: Dictionary[Outcome, Color] = {
	Outcome.CRITICAL_HIT: Color(1.0, 0.82, 0.2),
	Outcome.HIT: Color(0.95, 0.95, 0.92),
	Outcome.NARROW_HIT: Color(0.55, 0.78, 1.0),
	Outcome.MISS: Color(0.55, 0.55, 0.6),
	Outcome.NATURAL_ONE: Color(0.85, 0.18, 0.15),
	Outcome.HEAL: Color(0.45, 0.9, 0.45),
}
## Multiplied onto the ivory die face.
const DIE_TINTS: Dictionary[Outcome, Color] = {
	Outcome.CRITICAL_HIT: Color(1.0, 0.82, 0.3),
	Outcome.HIT: NEUTRAL_DIE_TINT,
	Outcome.NARROW_HIT: Color(0.8, 0.88, 1.0),
	Outcome.MISS: Color(0.55, 0.55, 0.58),
	Outcome.NATURAL_ONE: Color(0.55, 0.1, 0.1),
	Outcome.HEAL: Color(0.65, 1.0, 0.65),
}
const DIE_NUMBER_COLORS: Dictionary[Outcome, Color] = {
	Outcome.CRITICAL_HIT: NEUTRAL_DIE_NUMBER_COLOR,
	Outcome.HIT: NEUTRAL_DIE_NUMBER_COLOR,
	Outcome.NARROW_HIT: NEUTRAL_DIE_NUMBER_COLOR,
	Outcome.MISS: Color(0.25, 0.25, 0.27),
	Outcome.NATURAL_ONE: Color(1.0, 0.86, 0.82),
	Outcome.HEAL: NEUTRAL_DIE_NUMBER_COLOR,
}
## On reveal the die jumps to this scale and eases to its settled scale, so misses sag instead.
const REVEAL_SCALES: Dictionary[Outcome, float] = {
	Outcome.CRITICAL_HIT: 1.45,
	Outcome.HIT: 1.2,
	Outcome.NARROW_HIT: 1.1,
	Outcome.MISS: 1.0,
	Outcome.NATURAL_ONE: 1.0,
	Outcome.HEAL: 1.2,
}
const SETTLED_SCALES: Dictionary[Outcome, float] = {
	Outcome.CRITICAL_HIT: 1.0,
	Outcome.HIT: 1.0,
	Outcome.NARROW_HIT: 1.0,
	Outcome.MISS: 0.9,
	Outcome.NATURAL_ONE: 0.85,
	Outcome.HEAL: 1.0,
}

## When false, the play methods show the result at once and return without waiting.
var animations_enabled: bool = true
var _roll_count: int = 0
var _roll_step_durations: Array[float] = _make_roll_step_durations()
var _punch_tween: Tween

@onready var _title_label: Label = %TitleLabel
@onready var _die_face: PanelContainer = %DieFace
@onready var _die_label: Label = %DieLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _outcome_label: Label = %OutcomeLabel
@onready var _damage_label: Label = %DamageLabel


## Joins single dice results for display, for example "3 + 5".
static func join_dice_results(dice_results: Array[int]) -> String:
	var dice_texts: PackedStringArray = []
	for result: int in dice_results:
		dice_texts.append(str(result))
	return " + ".join(dice_texts)


## Every crit hits and a natural 1 always misses, so both are checked before the hit.
static func outcome_for(attack: AttackRoll) -> Outcome:
	if attack.is_natural_one:
		return Outcome.NATURAL_ONE
	if attack.is_crit:
		return Outcome.CRITICAL_HIT
	if attack.is_narrow_hit:
		return Outcome.NARROW_HIT
	if attack.is_hit:
		return Outcome.HIT
	return Outcome.MISS


## Rolls and reveals the result. The damage is null on a miss, as in Combat.attack_resolved.
## Call hold() afterwards to keep the result on screen.
func play_attack(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
) -> void:
	_start_roll("%s attacks %s" % [attacker.display_name, defender.display_name])
	await _roll_die(attack.natural_roll, AttackRoll.DIE_SIDES)
	var outcome: Outcome = outcome_for(attack)
	if outcome == Outcome.CRITICAL_HIT and animations_enabled:
		await _wait(CRIT_FREEZE_DURATION)
	_detail_label.text = (
		"%+d = %d vs AC %d" % [attack.attack_bonus, attack.total, attack.target_armor_class]
	)
	if damage != null:
		_damage_label.text = (
			"Damage: %s" % _describe_sum(damage.dice_results, damage.damage_bonus, damage.total)
		)
	_reveal(outcome, OUTCOME_TEXTS[outcome])


## Rolls and reveals the heal. Call hold() afterwards to keep the result on screen.
func play_heal(title: String, heal: HealRoll, restored: int) -> void:
	_start_roll(title)
	var dice_sum: int = heal.total - heal.heal_bonus
	await _roll_die(dice_sum, heal.dice_results.size() * heal.die_sides)
	_detail_label.text = "%+d = %d" % [heal.heal_bonus, heal.total]
	_reveal(Outcome.HEAL, "%s %d" % [OUTCOME_TEXTS[Outcome.HEAL], restored])


## Keeps the revealed result on screen for a moment.
func hold() -> void:
	if animations_enabled:
		await _wait(HOLD_DURATION)


func _start_roll(title: String) -> void:
	_title_label.text = title
	_detail_label.text = ""
	_outcome_label.text = ""
	_damage_label.text = ""
	if _punch_tween != null:
		_punch_tween.kill()
	_die_face.scale = Vector2.ONE
	_tint_die(NEUTRAL_DIE_TINT, NEUTRAL_DIE_NUMBER_COLOR)


func _roll_die(final_value: int, highest_value: int) -> void:
	_roll_count += 1
	if animations_enabled:
		# Starting from the result would give it away, so the faces start from the roll count.
		var face: int = _roll_count
		for step_duration: float in _roll_step_durations:
			face = (face + ROLL_FACE_STEP - 1) % highest_value + 1
			_die_label.text = str(face)
			await _wait(step_duration)
	_die_label.text = str(final_value)


func _reveal(outcome: Outcome, outcome_text: String) -> void:
	_outcome_label.text = outcome_text
	_outcome_label.add_theme_color_override("font_color", OUTCOME_COLORS[outcome])
	_tint_die(DIE_TINTS[outcome], DIE_NUMBER_COLORS[outcome])
	if animations_enabled:
		_punch_die(REVEAL_SCALES[outcome], SETTLED_SCALES[outcome])
	result_revealed.emit(outcome)


func _tint_die(tint: Color, number_color: Color) -> void:
	_die_face.self_modulate = tint
	_die_label.add_theme_color_override("font_color", number_color)


# The die face sits in a plain Control, so no container resets its scale while the tween runs.
func _punch_die(reveal_scale: float, settled_scale: float) -> void:
	_die_face.scale = Vector2.ONE * reveal_scale
	_punch_tween = create_tween()
	var punch: PropertyTweener = _punch_tween.tween_property(
		_die_face, "scale", Vector2.ONE * settled_scale, PUNCH_DURATION
	)
	punch.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A tween dies with this node, so freeing the scene mid-roll never resumes on a freed instance.
func _wait(seconds: float) -> void:
	await create_tween().tween_interval(seconds).finished


## The step durations grow from the first to the last face and add up to ROLL_DURATION.
func _make_roll_step_durations() -> Array[float]:
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for step: int in ROLL_STEPS:
		var progress: float = float(step) / (ROLL_STEPS - 1)
		var weight: float = lerpf(1.0, ROLL_SLOWDOWN, ease(progress, ROLL_EASE_CURVE))
		weights.append(weight)
		weight_sum += weight
	var durations: Array[float] = []
	for weight: float in weights:
		durations.append(ROLL_DURATION * weight / weight_sum)
	return durations


func _describe_sum(dice_results: Array[int], bonus: int, total: int) -> String:
	var sum_text: String = join_dice_results(dice_results)
	if bonus > 0:
		sum_text += " + %d" % bonus
	elif bonus < 0:
		sum_text += " - %d" % -bonus
	return "%s = %d" % [sum_text, total]
