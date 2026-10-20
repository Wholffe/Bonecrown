extends GutTest
## StatSheet: the visible character values and the before → after lines of skill and item cards.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const STRENGTH_TRAINING: SkillData = preload("res://scripts/data/skills/strength_training.tres")
const TOUGHNESS: SkillData = preload("res://scripts/data/skills/toughness.tres")
const ADRENALINE: SkillData = preload("res://scripts/data/skills/adrenaline.tres")
const BONE_PLATE: ArmorData = preload("res://scripts/data/items/bone_plate.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")
## [crit threshold, expected text]
const CRIT_RANGE_CASES: Array = [[20, "20"], [19, "19–20"], [18, "18–20"]]

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)


func _change_texts(changes: Array[StatSheet.Change]) -> Array[String]:
	var texts: Array[String] = []
	for change: StatSheet.Change in changes:
		texts.append("%s %s → %s" % [change.label, change.before, change.after])
	return texts


func test_rows_show_the_warriors_starting_values() -> void:
	var sheet: StatSheet = StatSheet.new(_warrior)

	assert_eq(sheet.value_of(StatSheet.LEVEL), "1")
	assert_eq(sheet.value_of(StatSheet.MAX_HIT_POINTS), "14")
	assert_eq(sheet.value_of(StatSheet.HIT_POINTS_PER_LEVEL), "+8")
	assert_eq(sheet.value_of(StatSheet.ARMOR_CLASS), "14")
	assert_eq(sheet.value_of(StatSheet.ATTACK), "+5")
	assert_eq(sheet.value_of(StatSheet.DAMAGE), "1d8+4")
	assert_eq(sheet.value_of(StatSheet.CRIT_RANGE), "20")
	assert_eq(sheet.value_of(StatSheet.DAMAGE_REDUCTION), "0")
	assert_eq(sheet.value_of(StatSheet.LOOT_ROLL), "d20+0")
	assert_eq(sheet.value_of("Strength"), "16 (+3)")
	assert_eq(sheet.value_of("Luck"), "10 (+0)")


func test_rows_keep_the_display_order() -> void:
	var sheet: StatSheet = StatSheet.new(_warrior)

	assert_eq(
		sheet.labels.slice(0, 3),
		[StatSheet.LEVEL, StatSheet.MAX_HIT_POINTS, StatSheet.HIT_POINTS_PER_LEVEL] as Array[String]
	)
	assert_eq(sheet.labels.back(), "Luck")


func test_crit_range_text(params: Array = use_parameters(CRIT_RANGE_CASES)) -> void:
	assert_eq(StatSheet.crit_range_text(params[0]), params[1])


func test_dice_text_shows_a_negative_bonus() -> void:
	assert_eq(StatSheet.dice_text(2, 6, -1), "2d6-1")


func test_equal_sheets_have_no_changes() -> void:
	var changes: Array[StatSheet.Change] = StatSheet.changes(
		StatSheet.new(_warrior), StatSheet.new(_warrior)
	)

	assert_eq(changes.size(), 0)


func test_sheet_shows_an_active_conditional_bonus() -> void:
	_warrior.learn_skill(ADRENALINE)
	_warrior.take_damage(7)

	assert_eq(StatSheet.new(_warrior).value_of(StatSheet.DAMAGE), "1d8+6")


func test_strength_preview_shows_attribute_attack_and_damage() -> void:
	var texts: Array[String] = _change_texts(StatSheet.preview_skill(_warrior, STRENGTH_TRAINING))

	assert_eq(
		texts,
		["Attack +5 → +6", "Damage 1d8+4 → 1d8+5", "Strength 16 (+3) → 18 (+4)"] as Array[String]
	)


func test_constitution_preview_shows_max_hp_and_hp_per_level() -> void:
	var texts: Array[String] = _change_texts(StatSheet.preview_skill(_warrior, TOUGHNESS))

	assert_eq(
		texts,
		(
			[
				"Max HP 14 → 15",
				"HP per level-up +8 → +9",
				"Constitution 14 (+2) → 16 (+3)",
			]
			as Array[String]
		)
	)


func test_preview_does_not_change_the_character() -> void:
	_warrior.take_damage(3)

	StatSheet.preview_skill(_warrior, TOUGHNESS)
	StatSheet.preview_item(_warrior, BONE_PLATE)

	assert_eq(_warrior.skills.size(), 2)
	assert_eq(_warrior.armor, WARRIOR.starting_armor)
	assert_eq(_warrior.hit_points, 11)
	assert_eq(_warrior.max_hit_points, 14)


func test_item_preview_shows_gains_and_drawbacks() -> void:
	var texts: Array[String] = _change_texts(StatSheet.preview_item(_warrior, BONE_PLATE))

	assert_eq(texts, ["AC 14 → 20", "Attack +5 → +3", "Damage 1d8+4 → 1d8+2"] as Array[String])


func test_item_preview_for_the_empty_talisman_slot() -> void:
	var texts: Array[String] = _change_texts(StatSheet.preview_item(_warrior, LUCKY_COIN))

	assert_eq(texts, ["Loot roll d20+0 → d20+1", "Luck 10 (+0) → 12 (+1)"] as Array[String])


func test_conditional_skill_preview_ignores_current_hit_points() -> void:
	_warrior.take_damage(10)

	assert_eq(StatSheet.preview_skill(_warrior, ADRENALINE).size(), 0)


func test_condition_note_names_the_hit_point_threshold() -> void:
	var notes: Array[String] = StatSheet.condition_notes(22, ADRENALINE.effects)

	assert_eq(notes, ["While at 11 HP or less (half of 22): Damage +2"] as Array[String])


func test_condition_note_rounds_half_down() -> void:
	var notes: Array[String] = StatSheet.condition_notes(23, ADRENALINE.effects)

	assert_eq(notes, ["While at 11 HP or less (half of 23): Damage +2"] as Array[String])


func test_plain_modifiers_have_no_condition_note() -> void:
	assert_eq(StatSheet.condition_notes(22, STRENGTH_TRAINING.effects).size(), 0)
