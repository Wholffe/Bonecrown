class_name LootRoll
extends RefCounted
## Outcome of one loot roll: the d20 with its bonuses, the rarity it reached and the item found.

const DIE_SIDES: int = 20

var natural_roll: int
var luck_bonus: int
## Loot bonus of the room itself, such as the elite room's.
var room_bonus: int
## The Blood Price's roll bonus if the player paid it, otherwise 0.
var blood_price_bonus: int
var total: int
## Rarity that the total reaches on the loot table's thresholds.
var rolled_rarity: ItemData.Rarity = ItemData.Rarity.UNSET
## Rarity of the find, after legendaries are held back in early rooms.
var rarity: ItemData.Rarity = ItemData.Rarity.UNSET
## An item of that rarity which the player does not wear yet, or null when none is left.
var item: ItemData = null


func _init(roll: int, luck: int, room: int, blood_price: int) -> void:
	assert(roll >= 1 and roll <= DIE_SIDES, "Natural roll must be a d20 result")
	natural_roll = roll
	luck_bonus = luck
	room_bonus = room
	blood_price_bonus = blood_price
	total = roll + luck + room + blood_price


## True when a legendary total only gave a rare find, because the room was too early.
func is_downgraded() -> bool:
	return rarity != rolled_rarity
