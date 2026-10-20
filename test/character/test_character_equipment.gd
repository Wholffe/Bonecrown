extends GutTest
## Equipment of Character: slots, the replaced item returned by equip() and item effects that count
## only while the item is worn.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const HONED_LONGSWORD: WeaponData = preload("res://scripts/data/items/honed_longsword.tres")
const BALANCED_LONGSWORD: WeaponData = preload("res://scripts/data/items/balanced_longsword.tres")
const HEADSMANS_GREATSWORD: WeaponData = preload(
	"res://scripts/data/items/headsmans_greatsword.tres"
)
const KNIGHTS_CHAIN_MAIL: ArmorData = preload("res://scripts/data/items/knights_chain_mail.tres")
const BONE_PLATE: ArmorData = preload("res://scripts/data/items/bone_plate.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
const VIGOR_AMULET: TalismanData = preload("res://scripts/data/items/vigor_amulet.tres")
const SKULL_IDOL: TalismanData = preload("res://scripts/data/items/skull_idol.tres")

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)


func test_starting_equipment_comes_from_the_class_data() -> void:
	assert_eq(_warrior.weapon, WARRIOR.starting_weapon)
	assert_eq(_warrior.armor, WARRIOR.starting_armor)


func test_talisman_slot_starts_empty() -> void:
	assert_null(_warrior.talisman)


func test_equipping_into_the_empty_talisman_slot_returns_null() -> void:
	var replaced: ItemData = _warrior.equip(LUCKY_COIN)

	assert_null(replaced)
	assert_eq(_warrior.talisman, LUCKY_COIN)


func test_equipping_a_weapon_returns_the_replaced_weapon() -> void:
	var replaced: ItemData = _warrior.equip(HONED_LONGSWORD)

	assert_eq(replaced, WARRIOR.starting_weapon)
	assert_eq(_warrior.weapon, HONED_LONGSWORD)


func test_equipping_armor_returns_the_replaced_armor() -> void:
	var replaced: ItemData = _warrior.equip(KNIGHTS_CHAIN_MAIL)

	assert_eq(replaced, WARRIOR.starting_armor)
	assert_eq(_warrior.armor, KNIGHTS_CHAIN_MAIL)


func test_equipping_a_talisman_returns_the_replaced_talisman() -> void:
	_warrior.equip(LUCKY_COIN)

	var replaced: ItemData = _warrior.equip(VIGOR_AMULET)

	assert_eq(replaced, LUCKY_COIN)
	assert_eq(_warrior.talisman, VIGOR_AMULET)


func test_equipping_an_item_leaves_the_other_slots_unchanged() -> void:
	_warrior.equip(LUCKY_COIN)

	_warrior.equip(HONED_LONGSWORD)

	assert_eq(_warrior.armor, WARRIOR.starting_armor)
	assert_eq(_warrior.talisman, LUCKY_COIN)


func test_equipping_leaves_the_class_data_untouched() -> void:
	var starting_weapon: WeaponData = WARRIOR.starting_weapon
	var starting_armor: ArmorData = WARRIOR.starting_armor

	_warrior.equip(HONED_LONGSWORD)
	_warrior.equip(KNIGHTS_CHAIN_MAIL)

	assert_eq(WARRIOR.starting_weapon, starting_weapon)
	assert_eq(WARRIOR.starting_armor, starting_armor)


func test_weapon_dice_come_from_the_worn_weapon() -> void:
	_warrior.equip(HEADSMANS_GREATSWORD)

	assert_eq(_warrior.get_damage_die_count(), 2)
	assert_eq(_warrior.get_damage_die_sides(), 6)


func test_weapon_effects_count_while_worn() -> void:
	_warrior.equip(HONED_LONGSWORD)

	assert_eq(_warrior.get_damage_bonus(), 5, "strength bonus 3 + Weapon Master 1 + Honed 1")


func test_armor_base_and_effects_count_while_worn() -> void:
	_warrior.equip(KNIGHTS_CHAIN_MAIL)

	assert_eq(_warrior.get_armor_class(), 16, "base 13 + dexterity bonus 1 + Knight's 2")


func test_talisman_effects_count_while_worn() -> void:
	_warrior.equip(SKULL_IDOL)

	assert_eq(_warrior.get_attack_bonus(), 8, "5 + 3")
	assert_eq(_warrior.get_damage_bonus(), 7, "4 + 3")
	assert_eq(_warrior.get_armor_class(), 11, "14 - 3")


func test_weapon_effects_stop_counting_after_the_swap() -> void:
	_warrior.equip(HONED_LONGSWORD)

	_warrior.equip(BALANCED_LONGSWORD)

	assert_eq(_warrior.get_damage_bonus(), 4, "Honed +1 damage is gone")
	assert_eq(_warrior.get_attack_bonus(), 7, "Balanced +2 attack counts")


func test_armor_effects_stop_counting_after_the_swap() -> void:
	_warrior.equip(BONE_PLATE)

	_warrior.equip(WARRIOR.starting_armor)

	assert_eq(_warrior.get_armor_class(), 14)
	assert_eq(_warrior.get_attack_bonus(), 5, "Bone Plate -2 attack is gone")
	assert_eq(_warrior.get_damage_bonus(), 4, "Bone Plate -2 damage is gone")


func test_talisman_effects_stop_counting_after_the_swap() -> void:
	_warrior.equip(LUCKY_COIN)

	_warrior.equip(VIGOR_AMULET)

	assert_eq(_warrior.attribute_value(Attributes.Kind.LUCK), WARRIOR.luck, "coin is gone")
	assert_eq(_warrior.attribute_value(Attributes.Kind.CONSTITUTION), 16, "14 + Vigor 2")
