class_name PopupLayer
extends Control
## Overlay for numbers that pop up over the cards. Each pop-up rises, fades and frees itself.

## Damage counts as high in the top quarter of the range its dice and bonus can reach.
const HIGH_DAMAGE_SHARE: float = 0.75
const DAMAGE_COLOR: Color = Color(1.0, 0.93, 0.88)
const HIGH_DAMAGE_COLOR: Color = Color(1.0, 0.6, 0.15)
const OUTLINE_COLOR: Color = Color(0.05, 0.05, 0.07)
const OUTLINE_SIZE: int = 6
const DAMAGE_FONT_SIZE: int = 30
const HIGH_DAMAGE_FONT_SIZE: int = 38
const CRIT_FONT_SIZE: int = 46
const MISS_FONT_SIZE: int = 22
const HEAL_FONT_SIZE: int = 30
const MISS_TEXT: String = "Miss"
## Where a pop-up starts, as a share of the card size: centered over the portrait.
const START_POINT: Vector2 = Vector2(0.5, 0.3)
const CENTER_PIVOT: Vector2 = Vector2(0.5, 0.5)
const RISE_DISTANCE: float = 56.0
const DURATION: float = 0.8
const FADE_DELAY: float = 0.4
const POP_IN_SCALE: float = 1.5
const POP_IN_DURATION: float = 0.15


## Measured from the lowest to the highest possible total, so a crit counts its double dice.
static func is_high_damage(damage: DamageRoll, die_sides: int) -> bool:
	var die_count: int = damage.dice_results.size()
	var lowest_total: int = maxi(die_count + damage.damage_bonus, DamageRoll.MINIMUM_DAMAGE)
	var highest_total: int = die_count * die_sides + damage.damage_bonus
	return damage.total >= lowest_total + (highest_total - lowest_total) * HIGH_DAMAGE_SHARE


## The damage is null on a miss, as in Combat.attack_resolved.
func show_attack(
	over: Control, outcome: DiceDisplay.Outcome, damage: DamageRoll, damage_die_sides: int
) -> void:
	match outcome:
		DiceDisplay.Outcome.MISS, DiceDisplay.Outcome.NATURAL_ONE:
			_add_popup(over, MISS_TEXT, DiceDisplay.OUTCOME_COLORS[outcome], MISS_FONT_SIZE)
		DiceDisplay.Outcome.CRITICAL_HIT:
			_add_popup(
				over, _damage_text(damage), DiceDisplay.OUTCOME_COLORS[outcome], CRIT_FONT_SIZE
			)
		_:
			if is_high_damage(damage, damage_die_sides):
				_add_popup(over, _damage_text(damage), HIGH_DAMAGE_COLOR, HIGH_DAMAGE_FONT_SIZE)
			else:
				_add_popup(over, _damage_text(damage), DAMAGE_COLOR, DAMAGE_FONT_SIZE)


func show_heal(over: Control, restored: int) -> void:
	var heal_color: Color = DiceDisplay.OUTCOME_COLORS[DiceDisplay.Outcome.HEAL]
	_add_popup(over, "+%d" % restored, heal_color, HEAL_FONT_SIZE)


func _damage_text(damage: DamageRoll) -> String:
	return "-%d" % damage.total


func _add_popup(over: Control, text: String, color: Color, font_size: int) -> void:
	var popup: Label = Label.new()
	popup.text = text
	# Theme overrides would only size the label a frame later, label settings do it at once.
	popup.label_settings = _make_label_settings(color, font_size)
	popup.pivot_offset_ratio = CENTER_PIVOT
	add_child(popup)
	popup.reset_size()
	var over_rect: Rect2 = over.get_global_rect()
	var start: Vector2 = over_rect.position + over_rect.size * START_POINT
	popup.position = get_global_transform().affine_inverse() * start - popup.size / 2.0
	popup.scale = Vector2.ONE * POP_IN_SCALE
	_animate_popup(popup)


# The tween is bound to the pop-up, so freeing the scene mid-flight stops it cleanly.
func _animate_popup(popup: Label) -> void:
	var tween: Tween = popup.create_tween().set_parallel()
	var pop_in: PropertyTweener = tween.tween_property(popup, "scale", Vector2.ONE, POP_IN_DURATION)
	pop_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rise: PropertyTweener = tween.tween_property(
		popup, "position:y", popup.position.y - RISE_DISTANCE, DURATION
	)
	rise.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, DURATION - FADE_DELAY).set_delay(FADE_DELAY)
	tween.chain().tween_callback(popup.queue_free)


func _make_label_settings(color: Color, font_size: int) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_color = color
	settings.font_size = font_size
	settings.outline_color = OUTLINE_COLOR
	settings.outline_size = OUTLINE_SIZE
	return settings
