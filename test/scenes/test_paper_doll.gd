extends GutTest
## Paper doll: one item slot per equipment slot and the class's pixel figure.

const PAPER_DOLL_SCENE: PackedScene = preload("res://scenes/ui/paper_doll.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const HEADSMANS_GREATSWORD: WeaponData = preload(
	"res://scripts/data/items/headsmans_greatsword.tres"
)
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")

var _warrior: Character
var _paper_doll: PaperDoll


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)
	_paper_doll = PAPER_DOLL_SCENE.instantiate() as PaperDoll
	add_child_autofree(_paper_doll)


func test_every_equipment_slot_has_a_place() -> void:
	for slot: int in ItemData.Slot.values():
		assert_has(PaperDoll.SLOT_SIDES, slot, "%s has no side" % ItemData.Slot.find_key(slot))


func test_slots_sit_on_their_side_of_the_figure() -> void:
	for slot: ItemData.Slot in PaperDoll.SLOT_SIDES:
		var column: Node = _paper_doll.item_slot(slot).get_parent()
		var expected: String = (
			"LeftSlots" if PaperDoll.SLOT_SIDES[slot] == SIDE_LEFT else "RightSlots"
		)
		assert_eq(String(column.name), expected, ItemData.Slot.find_key(slot))


func test_figure_is_the_class_figure_from_the_battlefield() -> void:
	_paper_doll.show_character(_warrior)

	var figure: FigureView = _paper_doll.figure()
	assert_eq(figure.shown_frame(), WARRIOR.figure_frames[0])
	assert_false(figure.is_facing_left())
	assert_true(figure.is_processing(), "it plays the same idle loop")


func test_worn_items_fill_their_slots() -> void:
	_paper_doll.show_character(_warrior)

	assert_eq(_paper_doll.item_slot(ItemData.Slot.WEAPON).item, WARRIOR.starting_weapon)
	assert_eq(_paper_doll.item_slot(ItemData.Slot.ARMOR).item, WARRIOR.starting_armor)


func test_slot_without_an_item_is_shown_empty() -> void:
	_paper_doll.show_character(_warrior)

	var talisman_slot: ItemSlot = _paper_doll.item_slot(ItemData.Slot.TALISMAN)
	assert_null(talisman_slot.item)
	assert_true(talisman_slot.is_dimmed(), "The empty slot shows its dimmed silhouette")


func test_showing_again_replaces_the_items() -> void:
	_paper_doll.show_character(_warrior)
	_warrior.equip(HEADSMANS_GREATSWORD)
	_warrior.equip(LUCKY_COIN)

	_paper_doll.show_character(_warrior)

	assert_eq(_paper_doll.item_slot(ItemData.Slot.WEAPON).item, HEADSMANS_GREATSWORD)
	assert_eq(_paper_doll.item_slot(ItemData.Slot.TALISMAN).item, LUCKY_COIN)
