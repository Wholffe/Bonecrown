extends GutTest
## Item slot: icon or dimmed silhouette, frame in the rarity color, caption, tooltip and clicks.

const ITEM_SLOT_SCENE: PackedScene = preload("res://scenes/ui/item_slot.tscn")
const LONGSWORD: WeaponData = preload("res://scripts/data/items/longsword.tres")
const CHAIN_MAIL: ArmorData = preload("res://scripts/data/items/chain_mail.tres")
const HONED_LONGSWORD: WeaponData = preload("res://scripts/data/items/honed_longsword.tres")
const BALANCED_LONGSWORD: WeaponData = preload("res://scripts/data/items/balanced_longsword.tres")
const RUNED_LONGSWORD: WeaponData = preload("res://scripts/data/items/runed_longsword.tres")
const HEADSMANS_GREATSWORD: WeaponData = preload(
	"res://scripts/data/items/headsmans_greatsword.tres"
)
## A weapon of each rarity and that rarity.
const RARITY_CASES: Array = [
	[HONED_LONGSWORD, ItemData.Rarity.COMMON],
	[BALANCED_LONGSWORD, ItemData.Rarity.UNCOMMON],
	[RUNED_LONGSWORD, ItemData.Rarity.RARE],
	[HEADSMANS_GREATSWORD, ItemData.Rarity.LEGENDARY],
]


func _create_slot() -> ItemSlot:
	var item_slot: ItemSlot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
	add_child_autofree(item_slot)
	return item_slot


func _caption(item_slot: ItemSlot) -> Label:
	return item_slot.get_node("%CaptionLabel") as Label


func _tooltip_labels(item_slot: ItemSlot) -> Array[Label]:
	var tooltip: Control = autofree(item_slot._make_custom_tooltip(item_slot.tooltip_text))
	var labels: Array[Label] = []
	for label: Node in tooltip.find_children("*", "Label", true, false):
		labels.append(label as Label)
	return labels


func _texts(labels: Array[Label]) -> Array[String]:
	var texts: Array[String] = []
	for label: Label in labels:
		texts.append(label.text)
	return texts


func _click(button: MouseButton) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = button
	click.pressed = true
	return click


func test_item_shows_its_icon_and_name() -> void:
	var item_slot: ItemSlot = _create_slot()

	item_slot.show_item(ItemData.Slot.WEAPON, HONED_LONGSWORD)

	assert_eq(item_slot.shown_icon(), HONED_LONGSWORD.icon)
	assert_false(item_slot.is_dimmed())
	assert_eq(_caption(item_slot).text, "Honed Longsword")
	assert_no_new_orphans()


func test_frame_has_the_rarity_color(params: Array = use_parameters(RARITY_CASES)) -> void:
	var item_slot: ItemSlot = _create_slot()

	item_slot.show_item(ItemData.Slot.WEAPON, params[0])

	assert_eq(
		item_slot.frame_color(),
		ItemSlot.RARITY_COLORS[params[1]],
		ItemData.Rarity.find_key(params[1])
	)
	assert_no_new_orphans()


func test_starting_item_has_a_neutral_frame() -> void:
	var item_slot: ItemSlot = _create_slot()

	item_slot.show_item(ItemData.Slot.WEAPON, LONGSWORD)

	assert_eq(LONGSWORD.rarity, ItemData.Rarity.UNSET, "Starting items have no rarity")
	assert_eq(item_slot.frame_color(), ItemSlot.NEUTRAL_FRAME_COLOR)
	assert_no_new_orphans()


func test_empty_slot_shows_the_dimmed_silhouette() -> void:
	var item_slot: ItemSlot = _create_slot()

	item_slot.show_item(ItemData.Slot.TALISMAN, null)

	assert_eq(item_slot.shown_icon(), ItemSlot.SLOT_SILHOUETTES[ItemData.Slot.TALISMAN])
	assert_true(item_slot.is_dimmed())
	assert_eq(item_slot.frame_color(), ItemSlot.EMPTY_FRAME_COLOR)
	assert_eq(_caption(item_slot).text, "Talisman")
	assert_no_new_orphans()


func test_item_in_a_slot_that_was_empty_is_not_dimmed() -> void:
	var item_slot: ItemSlot = _create_slot()
	item_slot.show_item(ItemData.Slot.ARMOR, null)

	item_slot.show_item(ItemData.Slot.ARMOR, CHAIN_MAIL)

	assert_eq(item_slot.shown_icon(), CHAIN_MAIL.icon)
	assert_false(item_slot.is_dimmed())
	assert_no_new_orphans()


func test_every_slot_has_a_name_and_a_silhouette() -> void:
	for slot: int in ItemData.Slot.values():
		assert_has(ItemSlot.SLOT_NAMES, slot, "name of %s" % ItemData.Slot.find_key(slot))
		assert_has(
			ItemSlot.SLOT_SILHOUETTES, slot, "silhouette of %s" % ItemData.Slot.find_key(slot)
		)


func test_item_shown_before_ready_appears_once_added() -> void:
	var item_slot: ItemSlot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
	item_slot.show_item(ItemData.Slot.ARMOR, CHAIN_MAIL)

	add_child_autofree(item_slot)

	assert_eq(item_slot.shown_icon(), CHAIN_MAIL.icon)
	assert_eq(_caption(item_slot).text, "Chain Mail")
	assert_no_new_orphans()


func test_caption_and_icon_size_can_be_set_before_ready() -> void:
	var item_slot: ItemSlot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
	item_slot.caption_visible = false
	item_slot.icon_size = 36.0

	add_child_autofree(item_slot)

	assert_false(_caption(item_slot).visible)
	assert_eq((item_slot.get_node("%Icon") as TextureRect).custom_minimum_size, Vector2(36.0, 36.0))
	assert_no_new_orphans()


func test_tooltip_names_the_item_its_rarity_slot_and_effect() -> void:
	var item_slot: ItemSlot = _create_slot()
	item_slot.show_item(ItemData.Slot.WEAPON, HONED_LONGSWORD)

	var labels: Array[Label] = _tooltip_labels(item_slot)

	assert_eq(_texts(labels), ["Honed Longsword", "Common", "Weapon", "+1 damage."])
	assert_eq(
		labels[1].get_theme_color("font_color"), ItemSlot.RARITY_COLORS[ItemData.Rarity.COMMON]
	)


func test_tooltip_of_a_starting_item_leaves_out_the_rarity() -> void:
	var item_slot: ItemSlot = _create_slot()
	item_slot.show_item(ItemData.Slot.WEAPON, LONGSWORD)

	assert_eq(_texts(_tooltip_labels(item_slot)), ["Longsword", "Weapon"])


func test_tooltip_of_an_empty_slot() -> void:
	var item_slot: ItemSlot = _create_slot()
	item_slot.show_item(ItemData.Slot.TALISMAN, null)

	assert_eq(_texts(_tooltip_labels(item_slot)), ["Talisman", "(empty)"])
	assert_ne(item_slot.tooltip_text, "", "Godot only shows a tooltip with a tooltip text")


func test_left_click_emits_clicked() -> void:
	var item_slot: ItemSlot = _create_slot()
	watch_signals(item_slot)

	item_slot._gui_input(_click(MOUSE_BUTTON_LEFT))

	assert_signal_emitted(item_slot, "clicked")


func test_right_click_does_not_emit_clicked() -> void:
	var item_slot: ItemSlot = _create_slot()
	watch_signals(item_slot)

	item_slot._gui_input(_click(MOUSE_BUTTON_RIGHT))

	assert_signal_not_emitted(item_slot, "clicked")
