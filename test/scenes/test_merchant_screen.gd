extends GutTest
## Merchant screen: the node's level-up, the offered items with prices, buying an item and buying
## healing.

const MERCHANT_SCENE: PackedScene = preload("res://scenes/map/merchant_screen.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
const SEED: int = 7
const RICH: int = 1000


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.enter_node(MapNode.new(4, 0, MapNode.Type.MERCHANT))


func _create() -> MerchantScreen:
	var screen: MerchantScreen = MERCHANT_SCENE.instantiate() as MerchantScreen
	add_child_autofree(screen)
	return screen


func _label_text(screen: MerchantScreen, node_name: String) -> String:
	return (screen.get_node("%" + node_name) as Label).text


func test_opening_applies_the_level_up() -> void:
	var screen: MerchantScreen = _create()

	assert_eq(RunState.player.level, 2)
	assert_string_contains(_label_text(screen, "LevelUpLabel"), "Level 2!")


func test_offers_the_stock_with_prices() -> void:
	var screen: MerchantScreen = _create()

	assert_eq(screen.offered_items().size(), ECONOMY.merchant_item_count)
	assert_eq(screen.get_node("%Offers").get_child_count(), ECONOMY.merchant_item_count)


func test_buying_an_item_equips_it_and_costs_gold() -> void:
	RunState.player.gold = RICH
	var screen: MerchantScreen = _create()
	var item: ItemData = screen.offered_items()[0]

	screen.buy(item)

	assert_eq(RunState.player.item_in_slot(item.get_slot()), item)
	assert_eq(RunState.player.gold, RICH - ECONOMY.item_prices[item.rarity])
	assert_string_contains(_label_text(screen, "StatusLabel"), "Gold %d" % RunState.player.gold)


func test_items_cannot_be_bought_without_gold() -> void:
	var screen: MerchantScreen = _create()
	var item: ItemData = screen.offered_items()[0]

	screen.buy(item)

	assert_ne(RunState.player.item_in_slot(item.get_slot()), item)
	assert_eq(RunState.player.gold, 0)


func test_buying_healing_heals_and_costs_gold() -> void:
	RunState.player.gold = ECONOMY.heal_price
	RunState.player.take_damage(8)
	var screen: MerchantScreen = _create()
	var hit_points_before: int = RunState.player.hit_points

	(screen.get_node("%HealButton") as Button).pressed.emit()

	assert_gt(RunState.player.hit_points, hit_points_before)
	assert_eq(RunState.player.gold, 0)
	assert_true((screen.get_node("%HealButton") as Button).disabled, "no gold left")
