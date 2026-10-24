extends GutTest
## MerchantStock: the offered items, prices by rarity, buying items and buying healing.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
const SEED_COUNT: int = 30
const EARLY_ROOM: int = 2
const LATE_ROOM: int = 8

var _player: Character


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)


func _stock(seed_value: int, room: int = LATE_ROOM) -> MerchantStock:
	return MerchantStock.new(DiceRoller.new(seed_value), LOOT_TABLE, ECONOMY, _player, room)


func test_offers_different_items_the_player_does_not_wear() -> void:
	for seed_value: int in SEED_COUNT:
		var stock: MerchantStock = _stock(seed_value)
		assert_eq(stock.items.size(), ECONOMY.merchant_item_count, "seed %d" % seed_value)
		for item: ItemData in stock.items:
			assert_eq(stock.items.count(item), 1, "seed %d: %s twice" % [seed_value, item.id])
			assert_does_not_have(_player.worn_items(), item, "seed %d" % seed_value)


func test_early_merchant_sells_no_legendary_item() -> void:
	for seed_value: int in SEED_COUNT:
		for item: ItemData in _stock(seed_value, EARLY_ROOM).items:
			assert_ne(item.rarity, ItemData.Rarity.LEGENDARY, "seed %d" % seed_value)


func test_price_follows_the_rarity() -> void:
	var stock: MerchantStock = _stock(1)

	for item: ItemData in stock.items:
		assert_eq(stock.price_of(item), ECONOMY.item_prices[item.rarity])


func test_buying_pays_equips_and_removes_the_item() -> void:
	var stock: MerchantStock = _stock(1)
	var item: ItemData = stock.items[0]
	_player.gold = stock.price_of(item) + 5

	stock.buy(item, _player)

	assert_eq(_player.gold, 5)
	assert_eq(_player.item_in_slot(item.get_slot()), item)
	assert_does_not_have(stock.items, item)


func test_buying_without_enough_gold_changes_nothing() -> void:
	var stock: MerchantStock = _stock(1)
	var item: ItemData = stock.items[0]
	_player.gold = stock.price_of(item) - 1

	assert_false(stock.can_buy(item, _player))
	stock.buy(item, _player)

	assert_push_error_count(1)
	assert_has(stock.items, item)
	assert_eq(_player.gold, stock.price_of(item) - 1)


func test_healing_pays_and_heals_its_share() -> void:
	var stock: MerchantStock = _stock(1)
	_player.take_damage(10)
	_player.gold = ECONOMY.heal_price

	var healed: int = stock.buy_heal(_player)

	assert_eq(healed, floori(_player.max_hit_points * ECONOMY.heal_percent / 100.0))
	assert_eq(_player.gold, 0)


func test_healing_cannot_be_bought_at_full_health_or_without_gold() -> void:
	var stock: MerchantStock = _stock(1)
	_player.gold = ECONOMY.heal_price
	assert_false(stock.can_buy_heal(_player), "full health")

	_player.take_damage(5)
	_player.gold = ECONOMY.heal_price - 1

	assert_false(stock.can_buy_heal(_player), "not enough gold")
