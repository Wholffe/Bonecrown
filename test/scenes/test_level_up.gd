extends GutTest
## Post-fight screen: level-up, Blood Price, loot roll and find, and the next step.

const LEVEL_UP_SCENE: PackedScene = preload("res://scenes/levelup/level_up.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const HONED_LONGSWORD: WeaponData = preload("res://scripts/data/items/honed_longsword.tres")
const REINFORCED_CHAIN_MAIL: ArmorData = preload(
	"res://scripts/data/items/reinforced_chain_mail.tres"
)
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
const SEED: int = 7
## Loot d20 5 (common), first common item.
const COMMON_FIND_ROLLS: Array[int] = [5, 1]
## Loot d20 5 (common), third common item: the Lucky Coin for the empty talisman slot.
const TALISMAN_FIND_ROLLS: Array[int] = [5, 3]
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)


func _create(rolls: Array[int]) -> LevelUp:
	RunState.dice = FixedDice.new(rolls)
	var level_up: LevelUp = LEVEL_UP_SCENE.instantiate() as LevelUp
	level_up.set_animations_enabled(false)
	add_child_autofree(level_up)
	return level_up


func _label_text(level_up: LevelUp, node_name: String) -> String:
	return (level_up.get_node("%" + node_name) as Label).text


func _button(level_up: LevelUp, node_name: String) -> Button:
	return level_up.get_node("%" + node_name) as Button


func _item_slot(level_up: LevelUp, node_name: String) -> ItemSlot:
	return level_up.get_node("%" + node_name) as ItemSlot


func _press(level_up: LevelUp, node_name: String) -> void:
	_button(level_up, node_name).pressed.emit()
	await wait_process_frames(1)


func test_opening_applies_the_level_up() -> void:
	var level_up: LevelUp = _create([])

	assert_eq(RunState.player.level, 2)
	assert_eq(_label_text(level_up, "TitleLabel"), "Room 1 cleared")
	assert_eq(_label_text(level_up, "LevelUpLabel"), "Level 2!   Max HP 14 → 22 (+8)")
	assert_eq(_label_text(level_up, "HitPointsLabel"), "HP 22 / 22")


func test_loot_info_shows_the_roll_bonus_and_thresholds() -> void:
	var level_up: LevelUp = _create([])

	assert_eq(
		_label_text(level_up, "LootInfoLabel"),
		"Loot roll d20+0   ·   10+ Uncommon   ·   17+ Rare   ·   20+ Legendary (from room 3 on)"
	)


func test_blood_price_is_hidden_after_the_first_room() -> void:
	var level_up: LevelUp = _create([])

	assert_false(_button(level_up, "BloodPriceButton").visible)


func test_blood_price_is_offered_from_the_second_room() -> void:
	RunState.room_number = 2
	var level_up: LevelUp = _create([])

	var button: Button = _button(level_up, "BloodPriceButton")
	assert_true(button.visible)
	assert_eq(button.text, "Pay 2 HP: loot roll d20+0 → d20+5")


func test_paying_the_blood_price_costs_hit_points() -> void:
	RunState.room_number = 2
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)

	await _press(level_up, "BloodPriceButton")

	assert_eq(RunState.player.hit_points, 20)
	assert_eq(_label_text(level_up, "HitPointsLabel"), "HP 20 / 22")
	assert_true(_label_text(level_up, "FindLabel").begins_with("Uncommon find"), "5 + 5 = 10")


func test_roll_shows_the_find_with_its_value_changes() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)

	await _press(level_up, "RollButton")

	assert_eq(_label_text(level_up, "FindLabel"), "Common find: Honed Longsword (Weapon)")
	var details: String = _label_text(level_up, "FindDetailsLabel")
	assert_string_contains(details, "Damage 1d8+4 → 1d8+5")
	assert_string_contains(details, "Replaces Longsword.")
	assert_true(_button(level_up, "TakeButton").visible)
	assert_true(_button(level_up, "RollButton").disabled)


func test_find_is_shown_next_to_the_worn_item() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)
	assert_false(level_up.get_node("%FindComparison").visible, "Hidden before the roll")

	await _press(level_up, "RollButton")

	assert_true(level_up.get_node("%FindComparison").visible)
	assert_eq(_item_slot(level_up, "WornSlot").item, WARRIOR.starting_weapon)
	assert_eq(_item_slot(level_up, "FoundSlot").item, HONED_LONGSWORD)


func test_find_for_an_empty_slot_is_shown_next_to_the_empty_slot() -> void:
	var level_up: LevelUp = _create(TALISMAN_FIND_ROLLS)

	await _press(level_up, "RollButton")

	var worn_slot: ItemSlot = _item_slot(level_up, "WornSlot")
	assert_eq(worn_slot.slot, ItemData.Slot.TALISMAN)
	assert_null(worn_slot.item)
	assert_eq(_item_slot(level_up, "FoundSlot").item, LUCKY_COIN)
	assert_string_contains(_label_text(level_up, "FindDetailsLabel"), "talisman slot is empty")


func test_take_equips_the_find_and_shows_next() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)
	await _press(level_up, "RollButton")

	await _press(level_up, "TakeButton")

	assert_eq(RunState.player.weapon, HONED_LONGSWORD)
	assert_true(_button(level_up, "NextButton").visible)


func test_fight_gives_gold() -> void:
	var level_up: LevelUp = _create([])

	var gold: int = ECONOMY.fight_gold + ECONOMY.gold_per_row
	assert_eq(RunState.player.gold, gold, "room 1")
	assert_eq(_label_text(level_up, "GoldLabel"), "Gold +%d (%d)" % [gold, gold])


func test_selling_keeps_the_worn_item_and_gives_gold() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)
	var gold_before: int = RunState.player.gold
	await _press(level_up, "RollButton")
	var sell_value: int = ECONOMY.sell_values[ItemData.Rarity.COMMON]
	assert_eq(_button(level_up, "LeaveButton").text, "Sell (+%d gold)" % sell_value)

	await _press(level_up, "LeaveButton")

	assert_eq(RunState.player.gold, gold_before + sell_value)
	assert_eq(_label_text(level_up, "FindDetailsLabel"), "Sold for %d gold." % sell_value)
	assert_eq(RunState.player.weapon, WARRIOR.starting_weapon)
	assert_true(_button(level_up, "NextButton").visible)


func test_nothing_new_goes_straight_to_next() -> void:
	RunState.player.equip(HONED_LONGSWORD)
	RunState.player.equip(REINFORCED_CHAIN_MAIL)
	RunState.player.equip(LUCKY_COIN)
	var level_up: LevelUp = _create([4])

	await _press(level_up, "RollButton")

	assert_eq(_label_text(level_up, "FindLabel"), "Common: Nothing new this time.")
	assert_false(_button(level_up, "TakeButton").visible)
	assert_true(_button(level_up, "NextButton").visible)


func test_legendary_total_in_an_early_room_names_the_rule() -> void:
	var level_up: LevelUp = _create([20, 1])

	await _press(level_up, "RollButton")

	assert_eq(
		_label_text(level_up, "FindLabel"),
		"Rare (legendary finds start in room 3) find: Runed Longsword (Weapon)"
	)


func test_next_leads_to_the_skill_tree_while_a_point_can_be_spent() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)
	await _press(level_up, "RollButton")

	await _press(level_up, "LeaveButton")

	assert_true(MapScreen.has_skill_point_to_spend())
	assert_eq(_button(level_up, "NextButton").text, "Skill Tree")


func test_next_leads_to_the_map_once_the_point_is_spent() -> void:
	var level_up: LevelUp = _create(COMMON_FIND_ROLLS)
	var strength_training: SkillNodeData = RunState.skill_tree.tree.trunk.nodes[0]
	RunState.skill_tree.learn(strength_training, RunState.player)
	await _press(level_up, "RollButton")

	await _press(level_up, "LeaveButton")

	assert_false(MapScreen.has_skill_point_to_spend())
	assert_eq(_button(level_up, "NextButton").text, "Map")


func test_character_button_toggles_the_sheet() -> void:
	var level_up: LevelUp = _create([])

	await _press(level_up, "CharacterButton")

	assert_true((level_up.get_node("%CharacterSheet") as CharacterSheet).visible)
