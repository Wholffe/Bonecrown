class_name LevelUp
extends Control
## Post-fight screen: the level-up, then the loot roll with its find, then the skill choice.

const NOTHING_FOUND_TEXT: String = "Nothing new this time."
const SKILL_CARD_WIDTH: float = 300.0
const DESCRIPTION_COLOR: Color = Color(0.7, 0.7, 0.75)
# Paths instead of preloads, because the battle scene leads here and a preload would form a cycle.
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"

var _rewards: RoomRewards
var _skill_buttons: Array[Button] = []
# Kept here, because tests set it before _ready(), when the dice display does not exist yet.
var _animations_enabled: bool = true

@onready var _title_label: Label = %TitleLabel
@onready var _character_button: Button = %CharacterButton
@onready var _level_up_label: Label = %LevelUpLabel
@onready var _hit_points_label: Label = %HitPointsLabel
@onready var _loot_info_label: Label = %LootInfoLabel
@onready var _roll_button: Button = %RollButton
@onready var _blood_price_button: Button = %BloodPriceButton
@onready var _dice_display: DiceDisplay = %DiceDisplay
@onready var _find_label: Label = %FindLabel
@onready var _find_comparison: HBoxContainer = %FindComparison
@onready var _worn_slot: ItemSlot = %WornSlot
@onready var _found_slot: ItemSlot = %FoundSlot
@onready var _find_details_label: Label = %FindDetailsLabel
@onready var _take_button: Button = %TakeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _skill_section: VBoxContainer = %SkillSection
@onready var _skill_cards: HBoxContainer = %SkillCards
@onready var _next_button: Button = %NextButton
@onready var _character_sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	_dice_display.animations_enabled = _animations_enabled
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
	_roll_button.pressed.connect(_on_roll_pressed.bind(false))
	_blood_price_button.pressed.connect(_on_roll_pressed.bind(true))
	_take_button.pressed.connect(_on_take_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_rewards = RunState.start_room_rewards()
	_rewards.level_up()
	_title_label.text = "Room %d cleared" % _rewards.room_number
	_level_up_label.text = (
		"Level %d!   Max HP %d → %d (+%d)"
		% [
			RunState.player.level,
			_rewards.max_hit_points_before_level_up,
			RunState.player.max_hit_points,
			_rewards.hit_points_gained(),
		]
	)
	_show_hit_points()
	_show_loot_offer()


## Tests and a later fast mode turn the roll animation off. Works before and after _ready().
func set_animations_enabled(enabled: bool) -> void:
	_animations_enabled = enabled
	if is_node_ready():
		_dice_display.animations_enabled = enabled


## The skills of the current offer, in card order. Empty until the loot step is done.
func offered_skills() -> Array[SkillData]:
	return _rewards.skill_offer


func choose_skill(skill: SkillData) -> void:
	_rewards.choose_skill(skill)
	for button: Button in _skill_buttons:
		button.disabled = true
	_show_hit_points()
	_show_next_step()


func _show_hit_points() -> void:
	_hit_points_label.text = (
		"HP %d / %d" % [RunState.player.hit_points, RunState.player.max_hit_points]
	)


func _show_loot_offer() -> void:
	var table: LootTableData = RunState.LOOT_TABLE
	var bonus: int = _rewards.loot_roll_bonus()
	var legendary_text: String = "%d+ Legendary" % table.legendary_from
	if _rewards.room_number < table.legendary_from_room:
		legendary_text += " (from room %d on)" % table.legendary_from_room
	_loot_info_label.text = (
		"Loot roll d%d%+d   ·   %d+ Uncommon   ·   %d+ Rare   ·   %s"
		% [LootRoll.DIE_SIDES, bonus, table.uncommon_from, table.rare_from, legendary_text]
	)
	_blood_price_button.visible = _rewards.is_blood_price_offered()
	if _blood_price_button.visible:
		_blood_price_button.text = (
			"Pay %d HP: loot roll d%d%+d → d%d%+d"
			% [
				_rewards.blood_price_cost(),
				LootRoll.DIE_SIDES,
				bonus,
				LootRoll.DIE_SIDES,
				bonus + _rewards.blood_price_roll_bonus(),
			]
		)
	_take_button.hide()
	_leave_button.hide()
	_skill_section.hide()
	_next_button.hide()


func _on_roll_pressed(pay_blood_price: bool) -> void:
	_roll_button.disabled = true
	_blood_price_button.disabled = true
	var loot: LootRoll = _rewards.roll_loot(pay_blood_price)
	_show_hit_points()
	var bonus: int = loot.total - loot.natural_roll
	await _dice_display.play_roll(
		"Loot roll",
		loot.natural_roll,
		LootRoll.DIE_SIDES,
		"%+d = %d" % [bonus, loot.total],
		ItemSlot.RARITY_NAMES[loot.rarity].to_upper(),
		ItemSlot.RARITY_COLORS[loot.rarity]
	)
	_show_find(loot)


func _show_find(loot: LootRoll) -> void:
	var rarity_text: String = ItemSlot.RARITY_NAMES[loot.rarity]
	if loot.is_downgraded():
		rarity_text = (
			"%s (legendary finds start in room %d)"
			% [rarity_text, RunState.LOOT_TABLE.legendary_from_room]
		)
	_find_label.add_theme_color_override("font_color", ItemSlot.RARITY_COLORS[loot.rarity])
	if loot.item == null:
		_find_label.text = "%s: %s" % [rarity_text, NOTHING_FOUND_TEXT]
		_find_details_label.text = ""
		_show_skill_offer()
		return
	var item: ItemData = loot.item
	var slot: ItemData.Slot = item.get_slot()
	_find_label.text = (
		"%s find: %s (%s)" % [rarity_text, item.display_name, ItemSlot.SLOT_NAMES[slot]]
	)
	_worn_slot.show_item(slot, RunState.player.item_in_slot(slot))
	_found_slot.show_item(slot, item)
	_find_comparison.show()
	_find_details_label.text = "\n".join(_find_detail_lines(item))
	_take_button.show()
	_leave_button.show()


func _find_detail_lines(item: ItemData) -> Array[String]:
	var lines: Array[String] = [item.description]
	for change: StatSheet.Change in StatSheet.preview_item(RunState.player, item):
		lines.append("%s %s → %s" % [change.label, change.before, change.after])
	var worn: ItemData = RunState.player.item_in_slot(item.get_slot())
	if worn == null:
		lines.append("Your %s slot is empty." % ItemSlot.SLOT_NAMES[item.get_slot()].to_lower())
	else:
		lines.append("Replaces %s. A find you leave is lost." % worn.display_name)
	return lines


func _on_take_pressed() -> void:
	_rewards.take_item()
	_find_details_label.text = "Equipped."
	_show_hit_points()
	_show_skill_offer()


func _on_leave_pressed() -> void:
	_find_details_label.text = "Left behind."
	_show_skill_offer()


func _show_skill_offer() -> void:
	_take_button.hide()
	_leave_button.hide()
	# The find text stays, the die makes room for the cards.
	_dice_display.hide()
	_skill_section.show()
	for skill: SkillData in _rewards.roll_skill_offer():
		_skill_cards.add_child(_create_skill_card(skill))
	if _skill_buttons.is_empty():
		_show_next_step()


func _create_skill_card(skill: SkillData) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(SKILL_CARD_WIDTH, 0)
	var layout: VBoxContainer = VBoxContainer.new()
	card.add_child(layout)
	var name_label: Label = Label.new()
	name_label.text = skill.display_name
	name_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(name_label)
	var lines: Array[String] = _skill_card_lines(skill)
	for index: int in lines.size():
		var line_label: Label = Label.new()
		line_label.text = lines[index]
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# The first line is the skill's description, the others are value changes.
		if index == 0:
			line_label.add_theme_color_override("font_color", DESCRIPTION_COLOR)
		layout.add_child(line_label)
	var button: Button = Button.new()
	button.text = "Choose"
	button.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	button.pressed.connect(choose_skill.bind(skill))
	layout.add_child(button)
	_skill_buttons.append(button)
	return card


## The description first, then the changes to the player's own values. Never chances.
func _skill_card_lines(skill: SkillData) -> Array[String]:
	var lines: Array[String] = [skill.description]
	var after: Character = RunState.player.copy()
	after.learn_skill(skill)
	for change: StatSheet.Change in StatSheet.preview_skill(RunState.player, skill):
		lines.append("%s %s → %s" % [change.label, change.before, change.after])
	lines.append_array(StatSheet.condition_notes(after.max_hit_points, skill.effects))
	return lines


func _show_next_step() -> void:
	_next_button.show()
	if RunState.is_last_fight_room():
		_title_label.text = "Run complete – all fight rooms cleared"
		_next_button.text = "Main Menu"
	else:
		_next_button.text = "Next Room"
	_next_button.grab_focus()


func _on_next_pressed() -> void:
	if RunState.is_last_fight_room():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return
	RunState.advance_room()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
