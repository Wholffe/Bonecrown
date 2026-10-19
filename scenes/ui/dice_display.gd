class_name DiceDisplay
extends PanelContainer
## Shows the current roll with a short animation: who rolls, the die, the total and the outcome.

const ROLL_DURATION: float = 0.35
const ROLL_STEP_DURATION: float = 0.05
const HOLD_DURATION: float = 0.4
# Deterministic stand-in for random faces while rolling. It is coprime to 20, so a d20 shows all.
const ROLL_FACE_STEP: int = 7

## When false, the play methods show the result at once and return without waiting.
var animations_enabled: bool = true
var _roll_count: int = 0

@onready var _title_label: Label = %TitleLabel
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


## Rolls and reveals the result. The damage is null on a miss, as in Combat.attack_resolved.
## Call hold() afterwards to keep the result on screen.
func play_attack(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
) -> void:
	_start_roll("%s attacks %s" % [attacker.display_name, defender.display_name])
	await _roll_die(attack.natural_roll, AttackRoll.DIE_SIDES)
	_detail_label.text = (
		"%+d = %d vs AC %d" % [attack.attack_bonus, attack.total, attack.target_armor_class]
	)
	_outcome_label.text = _describe_outcome(attack)
	if damage != null:
		_damage_label.text = (
			"Damage: %s" % _describe_sum(damage.dice_results, damage.damage_bonus, damage.total)
		)


## Rolls and reveals the heal. Call hold() afterwards to keep the result on screen.
func play_heal(title: String, heal: HealRoll, restored: int) -> void:
	_start_roll(title)
	var dice_sum: int = heal.total - heal.heal_bonus
	await _roll_die(dice_sum, heal.dice_results.size() * heal.die_sides)
	_detail_label.text = "%+d = %d" % [heal.heal_bonus, heal.total]
	_outcome_label.text = "HEALED %d" % restored


## Keeps the revealed result on screen for a moment.
func hold() -> void:
	if animations_enabled:
		await _wait(HOLD_DURATION)


func _start_roll(title: String) -> void:
	_title_label.text = title
	_detail_label.text = ""
	_outcome_label.text = ""
	_damage_label.text = ""


func _roll_die(final_value: int, highest_value: int) -> void:
	_roll_count += 1
	if animations_enabled:
		# Starting from the result would give it away, so the faces start from the roll count.
		var face: int = _roll_count
		for _step: int in roundi(ROLL_DURATION / ROLL_STEP_DURATION):
			face = (face + ROLL_FACE_STEP - 1) % highest_value + 1
			_die_label.text = str(face)
			await _wait(ROLL_STEP_DURATION)
	_die_label.text = str(final_value)


# A tween dies with this node, so freeing the scene mid-roll never resumes on a freed instance.
func _wait(seconds: float) -> void:
	await create_tween().tween_interval(seconds).finished


func _describe_outcome(attack: AttackRoll) -> String:
	if attack.is_natural_one:
		return "NATURAL 1"
	if attack.is_crit:
		return "CRITICAL HIT"
	if attack.is_hit:
		return "HIT"
	return "MISS"


func _describe_sum(dice_results: Array[int], bonus: int, total: int) -> String:
	var sum_text: String = join_dice_results(dice_results)
	if bonus > 0:
		sum_text += " + %d" % bonus
	elif bonus < 0:
		sum_text += " - %d" % -bonus
	return "%s = %d" % [sum_text, total]
