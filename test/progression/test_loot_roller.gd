extends GutTest
## Loot roll rules of LootRoller: rarity thresholds, legendaries held back, worn duplicates.

const UNCOMMON_FROM: int = 10
const RARE_FROM: int = 17
const LEGENDARY_FROM: int = 20
const LEGENDARY_ROOM: int = 3
const SEED: int = 4242
const ROLL_COUNT: int = 300
## FixedDice result for the item pick when a rarity has a single candidate.
const ONLY_CANDIDATE: int = 1
## [natural roll, luck bonus, room bonus, expected rarity], rolled in the legendary room.
const RARITY_CASES: Array = [
	[9, 0, 0, ItemData.Rarity.COMMON],
	[10, 0, 0, ItemData.Rarity.UNCOMMON],
	[16, 0, 0, ItemData.Rarity.UNCOMMON],
	[17, 0, 0, ItemData.Rarity.RARE],
	[19, 0, 0, ItemData.Rarity.RARE],
	[20, 0, 0, ItemData.Rarity.LEGENDARY],
	[8, 1, 0, ItemData.Rarity.COMMON],
	[9, 1, 0, ItemData.Rarity.UNCOMMON],
	[15, 1, 0, ItemData.Rarity.UNCOMMON],
	[16, 1, 0, ItemData.Rarity.RARE],
	[18, 1, 0, ItemData.Rarity.RARE],
	[19, 1, 0, ItemData.Rarity.LEGENDARY],
	[6, 0, 3, ItemData.Rarity.COMMON],
	[7, 0, 3, ItemData.Rarity.UNCOMMON],
	[13, 0, 3, ItemData.Rarity.UNCOMMON],
	[14, 0, 3, ItemData.Rarity.RARE],
	[16, 0, 3, ItemData.Rarity.RARE],
	[17, 0, 3, ItemData.Rarity.LEGENDARY],
	[4, 2, 3, ItemData.Rarity.COMMON],
	[5, 2, 3, ItemData.Rarity.UNCOMMON],
	[11, 2, 3, ItemData.Rarity.UNCOMMON],
	[12, 2, 3, ItemData.Rarity.RARE],
	[14, 2, 3, ItemData.Rarity.RARE],
	[15, 2, 3, ItemData.Rarity.LEGENDARY],
]

var _common: ItemData
var _uncommon: ItemData
var _rare: ItemData
var _legendary: ItemData
var _dice: FixedDice
# Not a const: Godot merges equal constant literals, so another empty typed const array in this
# script would share this instance and with it the element type.
var _no_worn_items: Array[StringName] = []


func before_each() -> void:
	_common = _item(&"test_common", ItemData.Rarity.COMMON)
	_uncommon = _item(&"test_uncommon", ItemData.Rarity.UNCOMMON)
	_rare = _item(&"test_rare", ItemData.Rarity.RARE)
	_legendary = _item(&"test_legendary", ItemData.Rarity.LEGENDARY)


func _item(id: StringName, rarity: ItemData.Rarity) -> ItemData:
	var item: TalismanData = TalismanData.new()
	item.id = id
	item.rarity = rarity
	return item


func _table(items: Array[ItemData]) -> LootTableData:
	var table: LootTableData = LootTableData.new()
	table.uncommon_from = UNCOMMON_FROM
	table.rare_from = RARE_FROM
	table.legendary_from = LEGENDARY_FROM
	table.legendary_from_room = LEGENDARY_ROOM
	table.items = items
	return table


func _one_item_per_rarity() -> LootTableData:
	return _table([_common, _uncommon, _rare, _legendary])


func _roller(rolls: Array[int], table: LootTableData) -> LootRoller:
	_dice = FixedDice.new(rolls)
	return LootRoller.new(_dice, table)


func test_rarity_follows_thresholds(params: Array = use_parameters(RARITY_CASES)) -> void:
	var roller: LootRoller = _roller([params[0], ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, params[1], params[2], false, _no_worn_items)

	assert_eq(loot.rarity, params[3], "%d + %d + %d" % [params[0], params[1], params[2]])


func test_total_adds_natural_roll_and_bonuses() -> void:
	var roller: LootRoller = _roller([7, ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, 1, 3, false, _no_worn_items)

	assert_eq(loot.natural_roll, 7)
	assert_eq(loot.luck_bonus, 1)
	assert_eq(loot.room_bonus, 3)
	assert_eq(loot.total, 11)


func test_total_below_one_is_common() -> void:
	var roller: LootRoller = _roller([1, ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, -1, 0, false, _no_worn_items)

	assert_eq(loot.total, 0)
	assert_eq(loot.rarity, ItemData.Rarity.COMMON)
	assert_eq(loot.item, _common)


func test_natural_twenty_is_not_legendary_by_itself() -> void:
	var roller: LootRoller = _roller([20, ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, -1, 0, false, _no_worn_items)

	assert_eq(loot.rarity, ItemData.Rarity.RARE, "20 - 1 = 19 stays below the threshold")


func test_natural_one_is_not_common_by_itself() -> void:
	var roller: LootRoller = _roller([1, ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, 2, 8, false, _no_worn_items)

	assert_eq(loot.rarity, ItemData.Rarity.UNCOMMON, "1 + 2 + 8 = 11")


func test_legendary_before_legendary_room_gives_rare() -> void:
	var roller: LootRoller = _roller([20, ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM - 1, 0, 0, false, _no_worn_items)

	assert_eq(loot.rolled_rarity, ItemData.Rarity.LEGENDARY)
	assert_eq(loot.rarity, ItemData.Rarity.RARE)
	assert_true(loot.is_downgraded())
	assert_eq(loot.item, _rare)


func test_legendary_from_legendary_room_stays_legendary() -> void:
	var roller: LootRoller = _roller([20, ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, 0, 0, false, _no_worn_items)

	assert_eq(loot.rarity, ItemData.Rarity.LEGENDARY)
	assert_false(loot.is_downgraded())
	assert_eq(loot.item, _legendary)


func test_rare_before_legendary_room_is_not_downgraded() -> void:
	var roller: LootRoller = _roller([18, ONLY_CANDIDATE], _one_item_per_rarity())

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM - 1, 0, 0, false, _no_worn_items)

	assert_eq(loot.rarity, ItemData.Rarity.RARE)
	assert_false(loot.is_downgraded())


func test_dice_pick_the_item_among_its_rarity() -> void:
	var second_common: ItemData = _item(&"test_second_common", ItemData.Rarity.COMMON)
	var roller: LootRoller = _roller([5, 2], _table([_common, _rare, second_common]))

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, 0, 0, false, _no_worn_items)

	assert_eq(loot.item, second_common, "The second of the two common items")


func test_worn_item_is_rerolled_within_its_rarity() -> void:
	var second_common: ItemData = _item(&"test_second_common", ItemData.Rarity.COMMON)
	var roller: LootRoller = _roller([5, ONLY_CANDIDATE], _table([_common, second_common]))
	var worn: Array[StringName] = [_common.id]

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, 0, 0, false, worn)

	assert_eq(loot.item, second_common)


func test_worn_items_are_never_found() -> void:
	var items: Array[ItemData] = [_common, _uncommon, _rare, _legendary]
	var worn: Array[StringName] = []
	for item: ItemData in items.duplicate():
		worn.append(item.id)
		items.append(_item(StringName("%s_spare" % item.id), item.rarity))
	var roller: LootRoller = LootRoller.new(DiceRoller.new(SEED), _table(items))

	for _i: int in ROLL_COUNT:
		var item: ItemData = roller.roll(LEGENDARY_ROOM, 0, 0, false, worn).item
		assert_true(item != null and item.id not in worn, "Every rarity has a spare to find")


func test_no_item_when_every_item_of_the_rarity_is_worn() -> void:
	var roller: LootRoller = _roller([5], _one_item_per_rarity())
	var worn: Array[StringName] = [_common.id]

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, 0, 0, false, worn)

	assert_eq(loot.rarity, ItemData.Rarity.COMMON)
	assert_null(loot.item)
	assert_eq(_dice.remaining_rolls(), 0)


func test_no_item_when_the_table_has_none_of_the_rarity() -> void:
	var roller: LootRoller = _roller([20], _table([_common, _uncommon, _rare]))

	var loot: LootRoll = roller.roll(LEGENDARY_ROOM, 0, 0, false, _no_worn_items)

	assert_eq(loot.rarity, ItemData.Rarity.LEGENDARY)
	assert_null(loot.item)
