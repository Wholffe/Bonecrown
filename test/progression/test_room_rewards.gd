extends GutTest
## RoomRewards: level-up, gold, Blood Price, loot roll, swap and selling after a fight or at a
## treasure.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
const HONED_LONGSWORD: WeaponData = preload("res://scripts/data/items/honed_longsword.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
const ELITE_LOOT_BONUS: int = 3
const FIRST_ROOM: int = 1
const BLOOD_PRICE_ROOM: int = 2

var _player: Character
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)


func _rewards(room_number: int, rolls: Array[int]) -> RoomRewards:
	_dice = FixedDice.new(rolls)
	return RoomRewards.new(_player, room_number, 0, _dice, LOOT_TABLE)


func _gold_rewards(room_number: int, rolls: Array[int]) -> RoomRewards:
	_dice = FixedDice.new(rolls)
	return RoomRewards.new(_player, room_number, 0, _dice, LOOT_TABLE, ECONOMY)


func test_room_bonus_adds_to_the_loot_roll() -> void:
	_dice = FixedDice.new([5, 1])
	var rewards: RoomRewards = RoomRewards.new(
		_player, FIRST_ROOM, ELITE_LOOT_BONUS, _dice, LOOT_TABLE
	)
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(false)

	assert_eq(rewards.loot_roll_bonus(), ELITE_LOOT_BONUS)
	assert_eq(loot.room_bonus, ELITE_LOOT_BONUS)
	assert_eq(loot.total, 5 + ELITE_LOOT_BONUS)


func test_fight_gold_is_base_plus_row_share() -> void:
	var rewards: RoomRewards = _gold_rewards(3, [])

	var gold: int = rewards.add_fight_gold(false)

	assert_eq(gold, ECONOMY.fight_gold + ECONOMY.gold_per_row * 3)
	assert_eq(_player.gold, gold)
	assert_eq(rewards.gold_gained, gold)


func test_elite_fight_gives_its_share_of_the_fight_gold() -> void:
	var rewards: RoomRewards = _gold_rewards(3, [])

	var gold: int = rewards.add_fight_gold(true)

	var normal: int = ECONOMY.fight_gold + ECONOMY.gold_per_row * 3
	assert_eq(gold, floori(normal * ECONOMY.elite_gold_percent / 100.0))


func test_treasure_gives_its_gold() -> void:
	var rewards: RoomRewards = _gold_rewards(FIRST_ROOM, [])

	assert_eq(rewards.add_treasure_gold(), ECONOMY.treasure_gold)
	assert_eq(_player.gold, ECONOMY.treasure_gold)


func test_selling_the_find_gives_its_rarity_value() -> void:
	var rewards: RoomRewards = _gold_rewards(FIRST_ROOM, [5, 1])
	rewards.level_up()
	var loot: LootRoll = rewards.roll_loot(false)
	var value: int = ECONOMY.sell_values[loot.item.rarity]

	assert_eq(rewards.sell_value(), value)
	assert_eq(rewards.sell_item(), value)
	assert_eq(_player.gold, value)
	assert_eq(_player.weapon, WARRIOR.starting_weapon, "Selling equips nothing")


func test_rewards_without_economy_give_no_gold() -> void:
	var rewards: RoomRewards = _rewards(3, [])

	assert_eq(rewards.add_fight_gold(true), 0)
	assert_eq(rewards.add_treasure_gold(), 0)
	assert_eq(_player.gold, 0)


func test_level_up_raises_level_and_reports_the_gain() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [])

	rewards.level_up()

	assert_eq(_player.level, 2)
	assert_eq(rewards.hit_points_gained(), 8)


func test_blood_price_is_not_offered_after_the_first_room() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [])
	rewards.level_up()

	assert_false(rewards.is_blood_price_offered())


func test_blood_price_costs_the_new_level_in_hit_points() -> void:
	var rewards: RoomRewards = _rewards(BLOOD_PRICE_ROOM, [])
	rewards.level_up()

	assert_true(rewards.is_blood_price_offered())
	assert_eq(rewards.blood_price_cost(), 2)
	assert_eq(rewards.blood_price_roll_bonus(), 5)


func test_paid_blood_price_costs_hit_points_and_adds_its_bonus() -> void:
	var rewards: RoomRewards = _rewards(BLOOD_PRICE_ROOM, [8, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(true)

	assert_eq(_player.hit_points, 20, "22 HP after the level-up, less 2")
	assert_eq(loot.total, 13)
	assert_eq(loot.rarity, ItemData.Rarity.UNCOMMON)


func test_blood_price_is_not_paid_when_it_is_not_offered() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [8, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(true)

	assert_eq(_player.hit_points, 22)
	assert_eq(loot.blood_price_bonus, 0)


func test_loot_roll_adds_the_luck_bonus() -> void:
	_player.equip(LUCKY_COIN)
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [9, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(false)

	assert_eq(rewards.loot_roll_bonus(), 1)
	assert_eq(loot.total, 10)
	assert_eq(loot.rarity, ItemData.Rarity.UNCOMMON)


func test_take_item_equips_the_find_and_returns_the_replaced_item() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [5, 1])
	rewards.level_up()
	var loot: LootRoll = rewards.roll_loot(false)

	var replaced: ItemData = rewards.take_item()

	assert_eq(loot.item, HONED_LONGSWORD)
	assert_eq(replaced, WARRIOR.starting_weapon)
	assert_eq(_player.weapon, HONED_LONGSWORD)


func test_leaving_the_find_keeps_the_worn_item() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [5, 1])
	rewards.level_up()

	rewards.roll_loot(false)

	assert_eq(_player.weapon, WARRIOR.starting_weapon)


func test_worn_item_is_not_found_again() -> void:
	_player.equip(HONED_LONGSWORD)
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [5, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(false)

	assert_ne(loot.item, HONED_LONGSWORD)
	assert_eq(loot.item.rarity, ItemData.Rarity.COMMON)
