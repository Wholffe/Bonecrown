class_name RoomRewards
extends RefCounted
## The rewards after a won fight, in the order the screen shows them: level-up, loot roll, skill
## choice. Each step changes the player right away, so the run state is plain data at any point.

var player: Character
## The room just won. Its loot is rolled here.
var room_number: int
var max_hit_points_before_level_up: int = 0
## Null until roll_loot().
var loot: LootRoll = null
var skill_offer: Array[SkillData] = []
var _room_loot_bonus: int
var _loot_table: LootTableData
var _loot_roller: LootRoller
var _skill_offer_roller: SkillOfferRoller


func _init(
	run_player: Character,
	won_room: int,
	room_loot_bonus: int,
	dice: DiceRoller,
	loot_table: LootTableData
) -> void:
	player = run_player
	room_number = won_room
	_room_loot_bonus = room_loot_bonus
	_loot_table = loot_table
	_loot_roller = LootRoller.new(dice, loot_table)
	_skill_offer_roller = SkillOfferRoller.new(dice)


func level_up() -> void:
	max_hit_points_before_level_up = player.max_hit_points
	player.level_up()


func hit_points_gained() -> int:
	return player.max_hit_points - max_hit_points_before_level_up


func is_blood_price_offered() -> bool:
	return _loot_roller.is_blood_price_offered(room_number, player.level, player.hit_points)


func blood_price_cost() -> int:
	return _loot_roller.blood_price_cost(player.level)


func blood_price_roll_bonus() -> int:
	return _loot_table.blood_price_roll_bonus


## Loot roll bonus without the Blood Price: Luck plus the room's own bonus.
func loot_roll_bonus() -> int:
	return player.loot_bonus() + _room_loot_bonus


## Pays the Blood Price first when pay_blood_price is true and it is offered.
func roll_loot(pay_blood_price: bool) -> LootRoll:
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
## Not calling it leaves the find behind, and it is lost.
func take_item() -> ItemData:
	assert(loot != null and loot.item != null, "There is no find to take")
	return player.equip(loot.item)


func roll_skill_offer() -> Array[SkillData]:
	skill_offer = _skill_offer_roller.roll_offer(
		player.class_data.skill_pool, player.level, player.skills, player.capped_attribute_stats()
	)
	return skill_offer


func choose_skill(skill: SkillData) -> void:
	assert(skill in skill_offer, "Only an offered skill can be chosen")
	player.learn_skill(skill)
