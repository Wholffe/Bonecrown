class_name EconomyData
extends Resource
## Gold, prices and healing on the map: fight gold, selling finds, the merchant, rest and treasure.

@export_group("Gold")
## Gold after a won fight: fight_gold + gold_per_row × row.
@export var fight_gold: int = 0
@export var gold_per_row: int = 0
## An elite fight gives this share of the normal fight gold.
@export var elite_gold_percent: int = 0
## Gold for a find that is left behind, by rarity, common first.
@export var sell_values: Array[int] = []
@export_group("Merchant")
@export var merchant_item_count: int = 0
## Price of an item by rarity, common first.
@export var item_prices: Array[int] = []
## One healing heals this share of the max hit points and can be bought again.
@export var heal_price: int = 0
@export var heal_percent: int = 0
@export_group("Rest and treasure")
@export var rest_heal_percent: int = 0
## Added to the loot roll of a treasure node.
@export var treasure_loot_bonus: int = 0
## Added on top for a sealed treasure, the reward for passing its check.
@export var sealed_treasure_loot_bonus: int = 0
@export var treasure_gold: int = 0
