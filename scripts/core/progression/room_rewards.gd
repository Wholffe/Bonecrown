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
## Null until choose_skill().
var chosen_skill: SkillData = null
## The reward of the door chosen before the fight, or null.
var door_reward: DoorRewardData = null
var _room_loot_bonus: int
var _loot_table: LootTableData
var _loot_roller: LootRoller
var _skill_offer_roller: SkillOfferRoller
var _has_leveled_up: bool = false


func _init(
	run_player: Character,
	won_room: int,
	room_loot_bonus: int,
	dice: DiceRoller,
	loot_table: LootTableData,
	chosen_door_reward: DoorRewardData = null
) -> void:
	player = run_player
	room_number = won_room
	door_reward = chosen_door_reward
	# The door's loot bonus counts as part of the room's own bonus, like the elite room's.
	_room_loot_bonus = room_loot_bonus
	if door_reward != null:
		_room_loot_bonus += door_reward.loot_bonus
	_loot_table = loot_table
	_loot_roller = LootRoller.new(dice, loot_table)
	_skill_offer_roller = SkillOfferRoller.new(dice)


## Heals the door reward's share of the max hit points, rounded down. The screen calls it once,
## before the level-up. Returns the hit points actually restored.
func heal_from_door_reward() -> int:
	if door_reward == null:
		return 0
	var amount: int = floori(player.max_hit_points * door_reward.heal_percent / 100.0)
	return player.heal(amount)


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


## Loot roll bonus without the Blood Price: Luck plus the room's own bonus and the door's.
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
## Not calling it leaves the find behind, and it is lost.
func take_item() -> ItemData:
	assert(loot != null and loot.item != null, "There is no find to take")
	return player.equip(loot.item)


func roll_skill_offer() -> Array[SkillData]:
	assert(_has_leveled_up, "The level-up comes before the skill offer")
	skill_offer = _skill_offer_roller.roll_offer(
		player.class_data.skill_pool, player.level, player.skills, _capped_attribute_stats()
	)
	return skill_offer


func choose_skill(skill: SkillData) -> void:
	assert(chosen_skill == null, "A room gives one skill")
	assert(skill in skill_offer, "Only an offered skill can be chosen")
	chosen_skill = skill
	player.learn_skill(skill)


func _capped_attribute_stats() -> Array[StatModifierEffect.Stat]:
	var capped: Array[StatModifierEffect.Stat] = []
	for kind: Attributes.Kind in Character.ATTRIBUTE_STATS:
		if player.is_attribute_capped(kind):
			capped.append(Character.ATTRIBUTE_STATS[kind])
	return capped
