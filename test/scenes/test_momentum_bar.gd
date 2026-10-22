extends GutTest
## Momentum bar: orbs per cap, filled orbs, the cost preview and the change note.

const MOMENTUM_BAR_SCENE: PackedScene = preload("res://scenes/ui/momentum_bar.tscn")


func _create_bar(value: int, cap: int) -> MomentumBar:
	var bar: MomentumBar = MOMENTUM_BAR_SCENE.instantiate() as MomentumBar
	bar.animations_enabled = false
	add_child_autofree(bar)
	bar.show_momentum(value, cap)
	return bar


func _orb_colors(bar: MomentumBar) -> Array[Color]:
	var colors: Array[Color] = []
	for slot: Node in bar.get_node("%Orbs").get_children():
		var face: Panel = slot.get_child(0) as Panel
		colors.append((face.get_theme_stylebox("panel") as StyleBoxFlat).bg_color)
	return colors


func test_one_orb_per_point_of_the_cap() -> void:
	var bar: MomentumBar = _create_bar(2, 4)

	assert_eq(bar.get_node("%Orbs").get_child_count(), 4)
	assert_eq((bar.get_node("%CountLabel") as Label).text, "2/4")


func test_filled_orbs_show_the_value() -> void:
	var bar: MomentumBar = _create_bar(3, 4)

	var filled: Color = MomentumBar.FILLED_COLOR
	var empty: Color = MomentumBar.EMPTY_COLOR
	assert_eq(_orb_colors(bar), [filled, filled, filled, empty])


func test_preview_marks_the_last_filled_orbs() -> void:
	var bar: MomentumBar = _create_bar(3, 4)

	bar.preview_cost(2)

	var filled: Color = MomentumBar.FILLED_COLOR
	var preview: Color = MomentumBar.PREVIEW_COLOR
	assert_eq(_orb_colors(bar), [filled, preview, preview, MomentumBar.EMPTY_COLOR])
	assert_eq(bar.previewed_orbs(), 2)


func test_unaffordable_or_zero_cost_clears_the_preview() -> void:
	var bar: MomentumBar = _create_bar(1, 4)
	bar.preview_cost(1)

	bar.preview_cost(2)

	assert_eq(bar.previewed_orbs(), 0)
	assert_false(MomentumBar.PREVIEW_COLOR in _orb_colors(bar))


func test_new_value_keeps_the_cap_and_updates_the_orbs() -> void:
	var bar: MomentumBar = _create_bar(4, 4)

	bar.show_momentum(1, 4)

	assert_eq(bar.shown_momentum(), 1)
	assert_eq(bar.get_node("%Orbs").get_child_count(), 4)
	assert_eq(_orb_colors(bar).count(MomentumBar.FILLED_COLOR), 1)


func test_change_note_names_the_reason() -> void:
	var bar: MomentumBar = _create_bar(2, 4)

	bar.show_change(1, "fended off")

	assert_eq(bar.change_text(), "+1 fended off")
