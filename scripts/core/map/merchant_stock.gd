class_name MerchantStock
extends RefCounted
## A merchant's offer: different items from the loot table that the player does not wear, priced
## by rarity, and healing that can be bought again while the player is hurt.

var items: Array[ItemData] = []
var _economy: EconomyData


## Legendary items wait for the loot table's legendary room, like loot finds.
func _init(
	dice: DiceRoller,
	loot_table: LootTableData,
	economy: EconomyData,
	character: Character,
	room_number: int
) -> void:
	_economy = economy
	var candidates: Array[ItemData] = []
	for item: ItemData in loot_table.items:
		if item in character.worn_items():
			continue
		if (
			item.rarity == ItemData.Rarity.LEGENDARY
			and room_number < loot_table.legendary_from_room
		):
			continue
		candidates.append(item)
	for _index: int in mini(economy.merchant_item_count, candidates.size()):
		var item: ItemData = candidates[dice.roll(candidates.size()) - 1]
		candidates.erase(item)
		items.append(item)


func price_of(item: ItemData) -> int:
	return _economy.item_prices[item.rarity]


func can_buy(item: ItemData, character: Character) -> bool:
	return item in items and character.gold >= price_of(item)


## Pays, equips the item and returns the item it replaces, or null for an empty slot.
func buy(item: ItemData, character: Character) -> ItemData:
	if not can_buy(item, character):
		push_error("%s cannot be bought now" % item.id)
		return null
	character.gold -= price_of(item)
	items.erase(item)
	return character.equip(item)


func heal_price() -> int:
	return _economy.heal_price


## The hit points one healing would restore, before the max hit points cap it.
func heal_amount(character: Character) -> int:
	return floori(character.max_hit_points * _economy.heal_percent / 100.0)


func can_buy_heal(character: Character) -> bool:
	return character.gold >= _economy.heal_price and character.hit_points < character.max_hit_points


## Returns the hit points actually restored.
func buy_heal(character: Character) -> int:
	if not can_buy_heal(character):
		push_error("Healing cannot be bought now")
		return 0
	character.gold -= _economy.heal_price
	return character.heal(heal_amount(character))
