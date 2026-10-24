extends GutTest
## Character sheet overlay: values, skills and the paper doll of the character, toggling and
## closing.

const CHARACTER_SHEET_SCENE: PackedScene = preload("res://scenes/ui/character_sheet.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const STRENGTH_TRAINING: SkillData = preload("res://scripts/data/skills/strength_training.tres")
const LUCKY_COIN: TalismanData = preload("res://scripts/data/items/lucky_coin.tres")

var _warrior: Character
var _sheet: CharacterSheet


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)
	_sheet = CHARACTER_SHEET_SCENE.instantiate() as CharacterSheet
	add_child_autofree(_sheet)
	_sheet.character = _warrior


func _press_key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_sheet._unhandled_input(event)


func test_sheet_starts_hidden() -> void:
	assert_false(_sheet.visible)


func test_open_shows_the_stat_rows() -> void:
	_warrior.take_damage(3)

	_sheet.open()

	assert_true(_sheet.visible)
	assert_eq(_sheet.stat_text(CharacterSheet.HIT_POINTS_LABEL), "11 / 14")
	assert_eq(_sheet.stat_text(StatSheet.ATTACK), "+5")
	assert_eq(_sheet.stat_text(StatSheet.DAMAGE), "1d8+4")
	assert_eq(_sheet.stat_text(StatSheet.CRIT_RANGE), "20")
	assert_eq(_sheet.stat_text("Strength"), "16 (+3)")


func test_open_lists_skills_with_their_descriptions() -> void:
	_sheet.open()

	var texts: Array[String] = _sheet.listed_texts()
	assert_has(texts, "Second Wind")
	assert_has(texts, "Weapon Master")
	assert_has(texts, "+1 damage with melee weapons.")


func test_stacked_skill_is_listed_once_with_its_count() -> void:
	_warrior.learn_skill(STRENGTH_TRAINING)
	_warrior.learn_skill(STRENGTH_TRAINING)

	_sheet.open()

	var texts: Array[String] = _sheet.listed_texts()
	assert_has(texts, "Strength Training ×2")
	assert_does_not_have(texts, "Strength Training")


func test_open_shows_the_worn_items_on_the_paper_doll() -> void:
	_sheet.open()

	var texts: Array[String] = _sheet.listed_texts()
	assert_has(texts, "Longsword")
	assert_has(texts, "Chain Mail")
	var paper_doll: PaperDoll = _sheet.get_node("%PaperDoll") as PaperDoll
	assert_eq(paper_doll.item_slot(ItemData.Slot.WEAPON).item.display_name, "Longsword")
	assert_null(paper_doll.item_slot(ItemData.Slot.TALISMAN).item, "No talisman at the start")


func test_reopening_shows_the_current_character() -> void:
	_sheet.open()
	_sheet.hide()
	_warrior.equip(LUCKY_COIN)

	_sheet.open()

	assert_has(_sheet.listed_texts(), "Lucky Coin")
	assert_eq(_sheet.stat_text(StatSheet.LOOT_ROLL), "d20+1")


func test_c_key_toggles_the_sheet() -> void:
	_press_key(CharacterSheet.TOGGLE_KEY)
	assert_true(_sheet.visible)

	_press_key(CharacterSheet.TOGGLE_KEY)

	assert_false(_sheet.visible)


func test_cancel_closes_the_open_sheet() -> void:
	_sheet.open()
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true

	_sheet._unhandled_input(cancel)

	assert_false(_sheet.visible)


func test_close_button_hides_the_sheet() -> void:
	_sheet.open()

	(_sheet.get_node("%CloseButton") as Button).pressed.emit()

	assert_false(_sheet.visible)


func test_other_keys_do_not_open_the_sheet() -> void:
	_press_key(KEY_X)

	assert_false(_sheet.visible)
