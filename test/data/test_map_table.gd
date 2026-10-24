extends GutTest
## Content rules of the map table and the economy: lanes and rows, node weights, skill checks,
## gold, prices and healing.

const MAP_TABLE: MapTableData = preload("res://scripts/data/map/map_table.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const RARITY_COUNT: int = 4


func test_map_has_lanes_paths_and_open_rows() -> void:
	assert_gt(MAP_TABLE.lane_count, 1, "lanes")
	assert_gt(MAP_TABLE.path_count, 1, "paths")
	assert_gt(MAP_TABLE.rest_row, RunMap.FIRST_ROW + 1, "at least one open row")
	assert_lt(MAP_TABLE.rest_row, GAME_RULES.room_count, "the rest comes before the boss")


func test_node_weights_are_not_negative_and_fights_are_possible() -> void:
	for weight: int in [
		MAP_TABLE.elite_weight,
		MAP_TABLE.merchant_weight,
		MAP_TABLE.rest_weight,
		MAP_TABLE.treasure_weight,
	]:
		assert_gte(weight, 0)
	assert_gt(MAP_TABLE.fight_weight, 0, "fight weight")


func test_first_rows_lie_in_the_open_rows() -> void:
	for first_row: int in [
		MAP_TABLE.elite_first_row,
		MAP_TABLE.merchant_first_row,
		MAP_TABLE.rest_first_row,
		MAP_TABLE.treasure_first_row,
	]:
		assert_between(first_row, RunMap.FIRST_ROW + 1, MAP_TABLE.rest_row - 1)


func test_skill_checks_have_texts_an_attribute_and_values() -> void:
	assert_between(MAP_TABLE.sealed_treasure_chance_percent, 0, 100)
	assert_false(MAP_TABLE.skill_checks.is_empty(), "No skill checks")
	assert_does_not_have(MAP_TABLE.skill_checks, null, "skill_checks has an empty slot")
	for check: SkillCheckData in MAP_TABLE.skill_checks:
		assert_ne(check.display_name, "", "%s display name" % check.id)
		assert_ne(check.action_text, "", "%s action text" % check.id)
		assert_ne(check.attribute, Attributes.Kind.UNSET, "%s attribute" % check.id)
		assert_between(check.difficulty, 2, SkillCheckRoll.DIE_SIDES, "%s difficulty" % check.id)
		assert_gt(check.fail_damage, 0, "%s fail damage" % check.id)


func test_gold_values_are_positive() -> void:
	assert_gt(ECONOMY.fight_gold, 0)
	assert_gte(ECONOMY.gold_per_row, 0)
	assert_gt(ECONOMY.elite_gold_percent, 100, "an elite gives more gold")
	assert_gt(ECONOMY.treasure_gold, 0)


# Rarer items are worth more, and a merchant sells for more than a find is worth.
func test_prices_and_sell_values_rise_with_rarity() -> void:
	assert_eq(ECONOMY.sell_values.size(), RARITY_COUNT)
	assert_eq(ECONOMY.item_prices.size(), RARITY_COUNT)
	for rarity: int in range(1, RARITY_COUNT):
		assert_gt(ECONOMY.sell_values[rarity], ECONOMY.sell_values[rarity - 1], "sell %d" % rarity)
		assert_gt(ECONOMY.item_prices[rarity], ECONOMY.item_prices[rarity - 1], "price %d" % rarity)
	for rarity: int in RARITY_COUNT:
		assert_gt(ECONOMY.item_prices[rarity], ECONOMY.sell_values[rarity], "margin %d" % rarity)


func test_merchant_rest_and_treasure_values_are_positive() -> void:
	assert_gt(ECONOMY.merchant_item_count, 0)
	assert_gt(ECONOMY.heal_price, 0)
	assert_between(ECONOMY.heal_percent, 1, 100)
	assert_between(ECONOMY.rest_heal_percent, 1, 100)
	assert_gt(ECONOMY.treasure_loot_bonus, 0)
	assert_gt(ECONOMY.sealed_treasure_loot_bonus, 0, "a passed check is worth something")
