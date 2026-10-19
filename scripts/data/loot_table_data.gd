class_name LootTableData
extends Resource
## Loot roll rules: rarity thresholds for d20 + bonus, Blood Price and the items that can drop.

## Lowest roll total for each rarity above common.
@export var uncommon_from: int = 0
@export var rare_from: int = 0
@export var legendary_from: int = 0
## First room whose loot can be legendary. Before it, a legendary total gives a rare item.
@export var legendary_from_room: int = 0
## Blood Price: before the roll, pay this many hit points per character level for the bonus.
@export var blood_price_hit_points_per_level: int = 0
@export var blood_price_roll_bonus: int = 0
## First room whose loot offers the Blood Price.
@export var blood_price_from_room: int = 0
@export var items: Array[ItemData] = []
