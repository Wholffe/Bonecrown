extends GutTest
## RoomRewards: door reward, level-up, Blood Price, loot roll and swap, skill offer and choice after
## a fight.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
const STRENGTH_TRAINING: SkillData = preload("res://scripts/data/skills/strength_training.tres")
const HONED_LONGSWORD: WeaponData = preload("res://scripts/data/items/honed_longsword.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
const TREASURE: DoorRewardData = preload("res://scripts/data/doors/treasure.tres")
const HEALING_SPRING: DoorRewardData = preload("res://scripts/data/doors/healing_spring.tres")
const ELITE_LOOT_BONUS: int = 3
const FIRST_ROOM: int = 1
const BLOOD_PRICE_ROOM: int = 2
const SEED: int = 99
const SEED_COUNT: int = 30

var _player: Character
var _dice: FixedDice


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)


func _rewards(room_number: int, rolls: Array[int]) -> RoomRewards:
	_dice = FixedDice.new(rolls)
	return RoomRewards.new(_player, room_number, 0, _dice, LOOT_TABLE)


func _door_rewards(reward: DoorRewardData) -> RoomRewards:
	return RoomRewards.new(_player, FIRST_ROOM, 0, FixedDice.new([]), LOOT_TABLE, reward)


func test_treasure_adds_to_the_room_loot_bonus() -> void:
	_dice = FixedDice.new([5, 1])
	var rewards: RoomRewards = RoomRewards.new(
		_player, FIRST_ROOM, ELITE_LOOT_BONUS, _dice, LOOT_TABLE, TREASURE
	)
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(false)

	assert_eq(rewards.loot_roll_bonus(), 6, "Elite +3 and Treasure +3")
	assert_eq(loot.room_bonus, 6)
	assert_eq(loot.total, 11)


func test_healing_spring_heals_its_share_of_max_hit_points_rounded_down() -> void:
	_player.take_damage(10)
	var rewards: RoomRewards = _door_rewards(HEALING_SPRING)

	var healed: int = rewards.heal_from_door_reward()

	assert_eq(healed, 1, "10% of 14 HP is 1.4")
	assert_eq(_player.hit_points, 5)


func test_healing_spring_heals_only_the_missing_hit_points() -> void:
	_player.take_damage(1)
	var rewards: RoomRewards = _door_rewards(HEALING_SPRING)

	assert_eq(rewards.heal_from_door_reward(), 1)
	assert_eq(_player.hit_points, _player.max_hit_points)


func test_door_rewards_without_a_heal_heal_nothing() -> void:
	_player.take_damage(10)

	assert_eq(_door_rewards(TREASURE).heal_from_door_reward(), 0, "Treasure")
	assert_eq(_door_rewards(null).heal_from_door_reward(), 0, "No door reward")
	assert_eq(_player.hit_points, 4)


func test_level_up_raises_level_and_reports_the_gain() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [])

	rewards.level_up()

	assert_eq(_player.level, 2)
	assert_eq(rewards.hit_points_gained(), 8)


func test_blood_price_is_not_offered_after_the_first_room() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [])
	rewards.level_up()

	assert_false(rewards.is_blood_price_offered())


func test_blood_price_costs_the_new_level_in_hit_points() -> void:
	var rewards: RoomRewards = _rewards(BLOOD_PRICE_ROOM, [])
	rewards.level_up()

	assert_true(rewards.is_blood_price_offered())
	assert_eq(rewards.blood_price_cost(), 2)
	assert_eq(rewards.blood_price_roll_bonus(), 5)


func test_paid_blood_price_costs_hit_points_and_adds_its_bonus() -> void:
	var rewards: RoomRewards = _rewards(BLOOD_PRICE_ROOM, [8, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(true)

	assert_eq(_player.hit_points, 20, "22 HP after the level-up, less 2")
	assert_eq(loot.total, 13)
	assert_eq(loot.rarity, ItemData.Rarity.UNCOMMON)


func test_blood_price_is_not_paid_when_it_is_not_offered() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [8, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(true)

	assert_eq(_player.hit_points, 22)
	assert_eq(loot.blood_price_bonus, 0)


func test_loot_roll_adds_the_luck_bonus() -> void:
	_player.equip(LUCKY_COIN)
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [9, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(false)

	assert_eq(rewards.loot_roll_bonus(), 1)
	assert_eq(loot.total, 10)
	assert_eq(loot.rarity, ItemData.Rarity.UNCOMMON)


func test_take_item_equips_the_find_and_returns_the_replaced_item() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [5, 1])
	rewards.level_up()
	var loot: LootRoll = rewards.roll_loot(false)

	var replaced: ItemData = rewards.take_item()

	assert_eq(loot.item, HONED_LONGSWORD)
	assert_eq(replaced, WARRIOR.starting_weapon)
	assert_eq(_player.weapon, HONED_LONGSWORD)


func test_leaving_the_find_keeps_the_worn_item() -> void:
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [5, 1])
	rewards.level_up()

	rewards.roll_loot(false)

	assert_eq(_player.weapon, WARRIOR.starting_weapon)


func test_worn_item_is_not_found_again() -> void:
	_player.equip(HONED_LONGSWORD)
	var rewards: RoomRewards = _rewards(FIRST_ROOM, [5, 1])
	rewards.level_up()

	var loot: LootRoll = rewards.roll_loot(false)

	assert_ne(loot.item, HONED_LONGSWORD)
	assert_eq(loot.item.rarity, ItemData.Rarity.COMMON)


func test_skill_offer_has_only_skills_of_the_new_level() -> void:
	for seed_value: int in SEED_COUNT:
		_player = Character.new(WARRIOR, GAME_RULES)
		var rewards: RoomRewards = RoomRewards.new(
			_player, FIRST_ROOM, 0, DiceRoller.new(seed_value), LOOT_TABLE
		)
		rewards.level_up()

		var offer: Array[SkillData] = rewards.roll_skill_offer()

		assert_eq(offer.size(), 3, "seed %d" % seed_value)
		for skill: SkillData in offer:
			assert_true(skill.min_level <= 2, "%s at level 2, seed %d" % [skill.id, seed_value])


func test_skill_offer_leaves_out_skills_of_a_capped_attribute() -> void:
	for seed_value: int in SEED_COUNT:
		_player = Character.new(WARRIOR, GAME_RULES)
		_player.learn_skill(STRENGTH_TRAINING)
		_player.learn_skill(STRENGTH_TRAINING)
		var rewards: RoomRewards = RoomRewards.new(
			_player, FIRST_ROOM, 0, DiceRoller.new(seed_value), LOOT_TABLE
		)
		rewards.level_up()

		assert_does_not_have(rewards.roll_skill_offer(), STRENGTH_TRAINING, "seed %d" % seed_value)


func test_chosen_skill_is_learned() -> void:
	var rewards: RoomRewards = RoomRewards.new(
		_player, FIRST_ROOM, 0, DiceRoller.new(SEED), LOOT_TABLE
	)
	rewards.level_up()
	var offer: Array[SkillData] = rewards.roll_skill_offer()

	rewards.choose_skill(offer[0])

	assert_has(_player.skills, offer[0])
	assert_eq(rewards.chosen_skill, offer[0])
