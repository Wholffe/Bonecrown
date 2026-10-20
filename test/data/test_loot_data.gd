extends GutTest
## Content rules of the loot table and of all items under scripts/data.

const DATA_ROOT: String = "res://scripts/data"
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
## Every rarity a loot roll can produce.
const LOOT_RARITIES: Array[ItemData.Rarity] = [
	ItemData.Rarity.COMMON,
	ItemData.Rarity.UNCOMMON,
	ItemData.Rarity.RARE,
	ItemData.Rarity.LEGENDARY,
]

var _items: Array[ItemData] = []


func before_all() -> void:
	for path: String in _find_resource_paths(DATA_ROOT):
		var item: ItemData = load(path) as ItemData
		if item != null:
			_items.append(item)


func _find_resource_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".tres"):
			paths.append(directory.path_join(file_name))
	for subdirectory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_find_resource_paths(directory.path_join(subdirectory)))
	return paths


func _has_negative_modifier(item: ItemData) -> bool:
	for effect: EffectData in item.effects:
		var modifier: StatModifierEffect = effect as StatModifierEffect
		if modifier != null and modifier.amount < 0:
			return true
	return false


# The slot is an int, because ItemData.Slot.values() yields plain ints.
func _loot_items_in(slot: int, rarity: ItemData.Rarity) -> Array[ItemData]:
	var found: Array[ItemData] = []
	for item: ItemData in LOOT_TABLE.items:
		if item != null and item.get_slot() == slot and item.rarity == rarity:
			found.append(item)
	return found


func test_items_exist() -> void:
	assert_gt(_items.size(), 0, "No items found under %s" % DATA_ROOT)


func test_loot_table_has_no_empty_item_slots() -> void:
	assert_does_not_have(LOOT_TABLE.items, null)


func test_loot_items_have_a_rarity() -> void:
	for item: ItemData in LOOT_TABLE.items:
		assert_ne(item.rarity, ItemData.Rarity.UNSET, "%s has no rarity" % item.id)


func test_loot_items_have_display_name_and_description() -> void:
	for item: ItemData in LOOT_TABLE.items:
		assert_ne(item.display_name, "", "%s has no display name" % item.id)
		assert_ne(item.description, "", "%s has no description" % item.id)


func test_loot_table_has_exactly_one_item_per_slot_and_rarity() -> void:
	for slot: int in ItemData.Slot.values():
		for rarity: ItemData.Rarity in LOOT_RARITIES:
			assert_eq(
				_loot_items_in(slot, rarity).size(),
				1,
				"%s %s" % [ItemData.Slot.find_key(slot), ItemData.Rarity.find_key(rarity)]
			)
	assert_eq(LOOT_TABLE.items.size(), ItemData.Slot.size() * LOOT_RARITIES.size())


func test_loot_thresholds_ascend() -> void:
	assert_lt(LOOT_TABLE.uncommon_from, LOOT_TABLE.rare_from)
	assert_lt(LOOT_TABLE.rare_from, LOOT_TABLE.legendary_from)


func test_loot_room_gates_and_blood_price_values_are_positive() -> void:
	assert_gt(LOOT_TABLE.legendary_from_room, 0, "legendary_from_room")
	assert_gt(LOOT_TABLE.blood_price_hit_points_per_level, 0, "blood_price_hit_points_per_level")
	assert_gt(LOOT_TABLE.blood_price_roll_bonus, 0, "blood_price_roll_bonus")
	assert_gt(LOOT_TABLE.blood_price_from_room, 0, "blood_price_from_room")


func test_talismans_have_effects() -> void:
	for item: ItemData in _items:
		if item is TalismanData:
			assert_gt(item.effects.size(), 0, "%s has no effects" % item.id)


func test_legendary_items_have_a_negative_modifier() -> void:
	for item: ItemData in _items:
		if item.rarity == ItemData.Rarity.LEGENDARY:
			assert_true(_has_negative_modifier(item), "%s has no drawback" % item.id)


# Mirrors Character._stat_modifier: only StatModifierEffect counts on worn items.
func test_item_effects_are_stat_modifiers() -> void:
	for item: ItemData in _items:
		for effect: EffectData in item.effects:
			assert_true(effect is StatModifierEffect, "%s has an effect without a rule" % item.id)
