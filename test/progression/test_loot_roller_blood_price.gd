extends GutTest
## Blood Price rules of LootRoller: when it is offered, what it costs and what it adds to the roll.

const UNCOMMON_FROM: int = 10
const RARE_FROM: int = 17
const LEGENDARY_FROM: int = 20
const BLOOD_PRICE_ROOM: int = 2
## Above the approved 1 per level, so the multiplication with the level shows.
const HIT_POINTS_PER_LEVEL: int = 2
const ROLL_BONUS: int = 5
const LEVEL: int = 3
## 3 levels at 2 hit points each.
const COST: int = 6
const PLENTY_OF_HIT_POINTS: int = 30
const NO_WORN_ITEMS: Array[StringName] = []

var _common: ItemData
var _uncommon: ItemData


func before_each() -> void:
	_common = _item(&"test_common", ItemData.Rarity.COMMON)
	_uncommon = _item(&"test_uncommon", ItemData.Rarity.UNCOMMON)


func _item(id: StringName, rarity: ItemData.Rarity) -> ItemData:
	var item: TalismanData = TalismanData.new()
	item.id = id
	item.rarity = rarity
	return item


func _roller(rolls: Array[int]) -> LootRoller:
	var table: LootTableData = LootTableData.new()
	table.uncommon_from = UNCOMMON_FROM
	table.rare_from = RARE_FROM
	table.legendary_from = LEGENDARY_FROM
	table.blood_price_hit_points_per_level = HIT_POINTS_PER_LEVEL
	table.blood_price_roll_bonus = ROLL_BONUS
	table.blood_price_from_room = BLOOD_PRICE_ROOM
	table.items = [_common, _uncommon]
	return LootRoller.new(FixedDice.new(rolls), table)


func test_cost_is_level_times_hit_points_per_level() -> void:
	assert_eq(_roller([]).blood_price_cost(LEVEL), COST)


func test_not_offered_before_its_room() -> void:
	var offered: bool = _roller([]).is_blood_price_offered(
		BLOOD_PRICE_ROOM - 1, LEVEL, PLENTY_OF_HIT_POINTS
	)

	assert_false(offered)


func test_offered_from_its_room() -> void:
	var offered: bool = _roller([]).is_blood_price_offered(
		BLOOD_PRICE_ROOM, LEVEL, PLENTY_OF_HIT_POINTS
	)

	assert_true(offered)


func test_not_offered_when_hit_points_equal_cost() -> void:
	var offered: bool = _roller([]).is_blood_price_offered(BLOOD_PRICE_ROOM, LEVEL, COST)

	assert_false(offered, "Paying would drop the player to 0 HP")


func test_offered_when_hit_points_exceed_cost() -> void:
	var offered: bool = _roller([]).is_blood_price_offered(BLOOD_PRICE_ROOM, LEVEL, COST + 1)

	assert_true(offered, "Paying leaves the player at 1 HP")


func test_paid_blood_price_adds_its_bonus_to_the_total() -> void:
	var roller: LootRoller = _roller([8, 1])

	var loot: LootRoll = roller.roll(BLOOD_PRICE_ROOM, 0, 0, true, NO_WORN_ITEMS)

	assert_eq(loot.blood_price_bonus, ROLL_BONUS)
	assert_eq(loot.total, 13)
	assert_eq(loot.rarity, ItemData.Rarity.UNCOMMON, "8 alone would be common")


func test_roll_without_blood_price_has_no_bonus() -> void:
	var roller: LootRoller = _roller([8, 1])

	var loot: LootRoll = roller.roll(BLOOD_PRICE_ROOM, 0, 0, false, NO_WORN_ITEMS)

	assert_eq(loot.blood_price_bonus, 0)
	assert_eq(loot.total, 8)
