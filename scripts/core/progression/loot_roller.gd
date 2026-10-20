class_name LootRoller
extends RefCounted
## Rolls the loot of a won room on a loot table and decides when the Blood Price is offered.

var _dice: DiceRoller
var _table: LootTableData


func _init(dice: DiceRoller, table: LootTableData) -> void:
	_dice = dice
	_table = table


## Hit points the Blood Price costs at the given character level (the level after the level-up).
func blood_price_cost(level: int) -> int:
	return level * _table.blood_price_hit_points_per_level


## room_number is the room whose loot it is, the one just won.
func is_blood_price_offered(room_number: int, level: int, current_hit_points: int) -> bool:
	# Paying must leave at least 1 hit point, so the player needs more hit points than it costs.
	return (
		room_number >= _table.blood_price_from_room and current_hit_points > blood_price_cost(level)
	)


## Rolls d20 + bonuses for the loot of room_number, the room just won.
## The caller checks is_blood_price_offered() first and takes blood_price_cost() off the player.
func roll(
	room_number: int,
	luck_bonus: int,
	room_bonus: int,
	uses_blood_price: bool,
	worn_item_ids: Array[StringName]
) -> LootRoll:
	var blood_price_bonus: int = _table.blood_price_roll_bonus if uses_blood_price else 0
	var loot: LootRoll = LootRoll.new(
		_dice.roll(LootRoll.DIE_SIDES), luck_bonus, room_bonus, blood_price_bonus
	)
	loot.rolled_rarity = _rarity_for_total(loot.total)
	loot.rarity = loot.rolled_rarity
	if loot.rarity == ItemData.Rarity.LEGENDARY and room_number < _table.legendary_from_room:
		loot.rarity = ItemData.Rarity.RARE
	loot.item = _pick_item(loot.rarity, worn_item_ids)
	return loot


func _rarity_for_total(total: int) -> ItemData.Rarity:
	if total < _table.uncommon_from:
		return ItemData.Rarity.COMMON
	if total < _table.rare_from:
		return ItemData.Rarity.UNCOMMON
	if total < _table.legendary_from:
		return ItemData.Rarity.RARE
	return ItemData.Rarity.LEGENDARY


## Leaving out the worn items rerolls a duplicate within its rarity.
func _pick_item(rarity: ItemData.Rarity, worn_item_ids: Array[StringName]) -> ItemData:
	var candidates: Array[ItemData] = []
	for item: ItemData in _table.items:
		if item.rarity == rarity and item.id not in worn_item_ids:
			candidates.append(item)
	if candidates.is_empty():
		return null
	return candidates[_dice.roll(candidates.size()) - 1]
