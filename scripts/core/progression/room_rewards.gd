class_name RoomRewards
extends RefCounted
## The rewards after a won fight or at a treasure, in the order the screen shows them: level-up,
## gold and loot roll. A find that is left behind turns into gold. The level-up's skill point is
## spent in the skill tree afterwards. Each step changes the player right away, so the run state is
## plain data at any point.

var player: Character
## The room just won. Its loot is rolled here.
var room_number: int
var max_hit_points_before_level_up: int = 0
## Null until roll_loot().
var loot: LootRoll = null
## All gold this room gave so far, for the screen.
var gold_gained: int = 0
var _room_loot_bonus: int
var _loot_table: LootTableData
var _loot_roller: LootRoller
## Null gives no gold.
var _economy: EconomyData
var _has_leveled_up: bool = false


func _init(
	run_player: Character,
	won_room: int,
	room_loot_bonus: int,
	dice: DiceRoller,
	loot_table: LootTableData,
	economy: EconomyData = null
) -> void:
	player = run_player
	room_number = won_room
	_room_loot_bonus = room_loot_bonus
	_loot_table = loot_table
	_loot_roller = LootRoller.new(dice, loot_table)
	_economy = economy


## The fight's gold: base and row share, an elite's share of it more.
func add_fight_gold(is_elite: bool) -> int:
	if _economy == null:
		return 0
	var gold: int = _economy.fight_gold + _economy.gold_per_row * room_number
	if is_elite:
		gold = floori(gold * _economy.elite_gold_percent / 100.0)
	return _gain_gold(gold)


func add_treasure_gold() -> int:
	return 0 if _economy == null else _gain_gold(_economy.treasure_gold)


## Leaves the find behind and sells it. Returns the gold it gave.
func sell_item() -> int:
	assert(loot != null and loot.item != null, "There is no find to sell")
	return 0 if _economy == null else _gain_gold(_economy.sell_values[loot.item.rarity])


## What leaving the find behind would give.
func sell_value() -> int:
	if _economy == null or loot == null or loot.item == null:
		return 0
	return _economy.sell_values[loot.item.rarity]


func level_up() -> void:
	max_hit_points_before_level_up = player.max_hit_points
	player.level_up()
	_has_leveled_up = true


func hit_points_gained() -> int:
	return player.max_hit_points - max_hit_points_before_level_up


func is_blood_price_offered() -> bool:
	return _loot_roller.is_blood_price_offered(room_number, player.level, player.hit_points)


func blood_price_cost() -> int:
	return _loot_roller.blood_price_cost(player.level)


func blood_price_roll_bonus() -> int:
	return _loot_table.blood_price_roll_bonus


## Loot roll bonus without the Blood Price: Luck plus the room's own bonus (elite or treasure).
func loot_roll_bonus() -> int:
	return player.loot_bonus() + _room_loot_bonus


## The table the loot is rolled on, for showing its thresholds.
func loot_table() -> LootTableData:
	return _loot_table


## Pays the Blood Price first when pay_blood_price is true and it is offered.
func roll_loot(pay_blood_price: bool) -> LootRoll:
	assert(_has_leveled_up, "The level-up comes before the loot roll")
	assert(loot == null, "The loot of a room is rolled once")
	var pays: bool = pay_blood_price and is_blood_price_offered()
	if pays:
		player.take_damage(blood_price_cost())
	var worn_ids: Array[StringName] = []
	for item: ItemData in player.worn_items():
		worn_ids.append(item.id)
	loot = _loot_roller.roll(room_number, player.loot_bonus(), _room_loot_bonus, pays, worn_ids)
	return loot


## Equips the found item and returns the item it replaces, or null for an empty slot.
func take_item() -> ItemData:
	assert(loot != null and loot.item != null, "There is no find to take")
	return player.equip(loot.item)


func _gain_gold(amount: int) -> int:
	player.gold += amount
	gold_gained += amount
	return amount
