extends GutTest
## Pop-ups over a card: text, color and size per outcome, start position, high damage and cleanup.

const POPUP_LAYER_SCENE: PackedScene = preload("res://scenes/ui/popup_layer.tscn")
const CARD_POSITION: Vector2 = Vector2(400, 120)
const CARD_SIZE: Vector2 = Vector2(180, 240)
const LONGSWORD_SIDES: int = 8
const POSITION_TOLERANCE: float = 0.5
## Extra time after the pop-up's own duration, so its queue_free() has run.
const FREE_MARGIN: float = 0.2
## Dice results, bonus, die sides and whether the total is high: at least 75 % of the highest total.
const HIGH_DAMAGE_CASES: Array = [
	[[8], 4, 8, true],
	[[7], 4, 8, true],
	[[6], 4, 8, false],
	[[8, 7], 4, 8, true],
	[[6, 4], 4, 8, false],
	[[5], 1, 6, true],
	[[4], 1, 6, false],
]


func _create_layer() -> PopupLayer:
	var layer: PopupLayer = POPUP_LAYER_SCENE.instantiate() as PopupLayer
	add_child_autofree(layer)
	return layer


func _create_card() -> Control:
	var card: Control = Control.new()
	add_child_autofree(card)
	card.position = CARD_POSITION
	card.size = CARD_SIZE
	return card


func _damage(dice_results: Array[int], bonus: int) -> DamageRoll:
	return DamageRoll.new(dice_results, bonus)


func _only_popup(layer: PopupLayer) -> Label:
	assert_eq(layer.get_child_count(), 1, "One pop-up per call")
	return layer.get_child(0) as Label


func _assert_look(popup: Label, text: String, color: Color, font_size: int) -> void:
	assert_eq(popup.text, text, "Text")
	assert_eq(popup.label_settings.font_color, color, "Color")
	assert_eq(popup.label_settings.font_size, font_size, "Font size")


func test_hit_shows_the_damage_in_the_damage_color() -> void:
	var layer: PopupLayer = _create_layer()

	var outcome: DiceDisplay.Outcome = DiceDisplay.Outcome.HIT
	layer.show_attack(_create_card(), outcome, _damage([3], 4), LONGSWORD_SIDES)

	var popup: Label = _only_popup(layer)
	_assert_look(popup, "-7", PopupLayer.DAMAGE_COLOR, PopupLayer.DAMAGE_FONT_SIZE)
	assert_no_new_orphans()


func test_narrow_hit_shows_the_damage_like_a_hit() -> void:
	var layer: PopupLayer = _create_layer()

	var outcome: DiceDisplay.Outcome = DiceDisplay.Outcome.NARROW_HIT
	layer.show_attack(_create_card(), outcome, _damage([2], 4), LONGSWORD_SIDES)

	var popup: Label = _only_popup(layer)
	_assert_look(popup, "-6", PopupLayer.DAMAGE_COLOR, PopupLayer.DAMAGE_FONT_SIZE)
	assert_no_new_orphans()


func test_high_damage_is_larger_and_in_its_own_color() -> void:
	var layer: PopupLayer = _create_layer()

	var outcome: DiceDisplay.Outcome = DiceDisplay.Outcome.HIT
	layer.show_attack(_create_card(), outcome, _damage([7], 4), LONGSWORD_SIDES)

	var popup: Label = _only_popup(layer)
	_assert_look(popup, "-11", PopupLayer.HIGH_DAMAGE_COLOR, PopupLayer.HIGH_DAMAGE_FONT_SIZE)
	assert_no_new_orphans()


func test_crit_damage_is_largest_and_in_the_crit_color() -> void:
	var layer: PopupLayer = _create_layer()

	var outcome: DiceDisplay.Outcome = DiceDisplay.Outcome.CRITICAL_HIT
	layer.show_attack(_create_card(), outcome, _damage([2, 1], 4), LONGSWORD_SIDES)

	var popup: Label = _only_popup(layer)
	var crit_color: Color = DiceDisplay.OUTCOME_COLORS[outcome]
	_assert_look(popup, "-7", crit_color, PopupLayer.CRIT_FONT_SIZE)
	assert_no_new_orphans()


func test_miss_is_small_and_grey() -> void:
	var layer: PopupLayer = _create_layer()

	var outcome: DiceDisplay.Outcome = DiceDisplay.Outcome.MISS
	layer.show_attack(_create_card(), outcome, null, LONGSWORD_SIDES)

	var popup: Label = _only_popup(layer)
	var miss_color: Color = DiceDisplay.OUTCOME_COLORS[outcome]
	_assert_look(popup, PopupLayer.MISS_TEXT, miss_color, PopupLayer.MISS_FONT_SIZE)
	assert_no_new_orphans()


func test_natural_one_misses_in_the_natural_one_color() -> void:
	var layer: PopupLayer = _create_layer()

	var outcome: DiceDisplay.Outcome = DiceDisplay.Outcome.NATURAL_ONE
	layer.show_attack(_create_card(), outcome, null, LONGSWORD_SIDES)

	var popup: Label = _only_popup(layer)
	var natural_one_color: Color = DiceDisplay.OUTCOME_COLORS[outcome]
	_assert_look(popup, PopupLayer.MISS_TEXT, natural_one_color, PopupLayer.MISS_FONT_SIZE)
	assert_no_new_orphans()


func test_heal_shows_the_restored_hit_points_in_the_heal_color() -> void:
	var layer: PopupLayer = _create_layer()

	layer.show_heal(_create_card(), 4)

	var popup: Label = _only_popup(layer)
	var heal_color: Color = DiceDisplay.OUTCOME_COLORS[DiceDisplay.Outcome.HEAL]
	_assert_look(popup, "+4", heal_color, PopupLayer.HEAL_FONT_SIZE)
	assert_no_new_orphans()


func test_high_damage_threshold(params: Array = use_parameters(HIGH_DAMAGE_CASES)) -> void:
	var dice_results: Array[int] = []
	dice_results.assign(params[0])
	var damage: DamageRoll = _damage(dice_results, params[1])

	var is_high: bool = PopupLayer.is_high_damage(damage, params[2])

	assert_eq(is_high, params[3], "%s + %d on d%d" % [dice_results, params[1], params[2]])


func test_popup_starts_centered_over_the_portrait_of_the_card() -> void:
	var layer: PopupLayer = _create_layer()
	var card: Control = _create_card()

	layer.show_heal(card, 4)

	var popup: Label = _only_popup(layer)
	var popup_center: Vector2 = popup.get_global_rect().get_center()
	var expected: Vector2 = CARD_POSITION + CARD_SIZE * PopupLayer.START_POINT
	assert_almost_eq(popup_center.x, expected.x, POSITION_TOLERANCE, "Centered on the card")
	assert_almost_eq(popup_center.y, expected.y, POSITION_TOLERANCE, "Over the portrait")
	assert_no_new_orphans()


func test_popup_frees_itself_after_it_faded() -> void:
	var layer: PopupLayer = _create_layer()
	layer.show_heal(_create_card(), 4)

	await wait_seconds(PopupLayer.DURATION + FREE_MARGIN)

	assert_eq(layer.get_child_count(), 0, "The pop-up is gone")
	assert_no_new_orphans()


func test_layer_and_popups_let_clicks_through_to_the_cards() -> void:
	var layer: PopupLayer = _create_layer()

	layer.show_heal(_create_card(), 4)

	assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Layer")
	assert_eq(_only_popup(layer).mouse_filter, Control.MOUSE_FILTER_IGNORE, "Pop-up")
	assert_no_new_orphans()
