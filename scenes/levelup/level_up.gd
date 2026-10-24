class_name LevelUp
extends Control
## Screen after a won fight or at a treasure node: the level-up and gold, a sealed treasure's
## check, then the loot roll with its find. The skill tree or the map follows.

const NOTHING_FOUND_TEXT: String = "Nothing new this time."
const SUCCESS_COLOR: Color = Color(0.55, 0.85, 0.45)
const FAILURE_COLOR: Color = Color(0.85, 0.4, 0.35)

var _rewards: RoomRewards
# Kept here, because tests set it before _ready(), when the dice display does not exist yet.
var _animations_enabled: bool = true

@onready var _title_label: Label = %TitleLabel
@onready var _character_button: Button = %CharacterButton
@onready var _level_up_label: Label = %LevelUpLabel
@onready var _hit_points_label: Label = %HitPointsLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _loot_info_label: Label = %LootInfoLabel
@onready var _check_button: Button = %CheckButton
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
@onready var _next_button: Button = %NextButton
@onready var _character_sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	_dice_display.animations_enabled = _animations_enabled
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
	_check_button.pressed.connect(_on_check_pressed)
	_roll_button.pressed.connect(_on_roll_pressed.bind(false))
	_blood_price_button.pressed.connect(_on_roll_pressed.bind(true))
	_take_button.pressed.connect(_on_take_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_rewards = RunState.start_room_rewards()
	_rewards.level_up()
	_title_label.text = _title_text()
	_level_up_label.text = level_up_text(_rewards)
	_show_hit_points()
	_show_loot_offer()
	var check: SkillCheckData = _sealing_check()
	if check != null:
		_show_check(check)
	elif RunState.is_treasure_node():
		_rewards.add_treasure_gold()
	else:
		_rewards.add_fight_gold(RunState.is_elite_node())
	_show_gold()


## "Level 3!   Max HP 22 → 30 (+8)". Every node's screen shows it after the level-up.
static func level_up_text(rewards: RoomRewards) -> String:
	return (
		"Level %d!   Max HP %d → %d (+%d)"
		% [
			rewards.player.level,
			rewards.max_hit_points_before_level_up,
			rewards.player.max_hit_points,
			rewards.hit_points_gained(),
		]
	)


## Tests and a later fast mode turn the roll animation off. Works before and after _ready().
func set_animations_enabled(enabled: bool) -> void:
	_animations_enabled = enabled
	if is_node_ready():
		_dice_display.animations_enabled = enabled


func _show_hit_points() -> void:
	_hit_points_label.text = (
		"HP %d / %d" % [RunState.player.hit_points, RunState.player.max_hit_points]
	)


func _show_gold() -> void:
	_gold_label.text = "Gold +%d (%d)" % [_rewards.gold_gained, RunState.player.gold]


func _title_text() -> String:
	if not RunState.is_treasure_node():
		return "Room %d cleared" % _rewards.room_number
	var check: SkillCheckData = _sealing_check()
	return "Treasure" if check == null else "Sealed Treasure: %s" % check.display_name


func _sealing_check() -> SkillCheckData:
	return RunState.current_node.check if RunState.is_treasure_node() else null


func _show_check(check: SkillCheckData) -> void:
	_roll_button.hide()
	_blood_price_button.hide()
	_check_button.show()
	_check_button.text = (
		"%s: %s check d%d%+d against %d"
		% [
			check.action_text,
			StatSheet.ATTRIBUTE_LABELS[check.attribute],
			SkillCheckRoll.DIE_SIDES,
			RunState.player.attribute_bonus(check.attribute),
			check.difficulty,
		]
	)


func _on_check_pressed() -> void:
	_check_button.disabled = true
	var check: SkillCheckData = _sealing_check()
	var result: SkillCheckRoll = RunState.create_map_events().roll_check(RunState.player, check)
	_show_hit_points()
	await _dice_display.play_roll(
		"%s check" % StatSheet.ATTRIBUTE_LABELS[check.attribute],
		result.natural_roll,
		SkillCheckRoll.DIE_SIDES,
		"%+d = %d" % [result.attribute_bonus, result.total],
		"SUCCESS" if result.is_success else "FAILED",
		SUCCESS_COLOR if result.is_success else FAILURE_COLOR
	)
	_check_button.hide()
	if not result.is_success:
		_find_label.text = "The treasure stays sealed. −%d HP" % check.fail_damage
		_find_label.add_theme_color_override("font_color", FAILURE_COLOR)
		_show_next_step()
		return
	_rewards.add_treasure_gold()
	_show_gold()
	_roll_button.show()
	_blood_price_button.visible = _rewards.is_blood_price_offered()


func _show_loot_offer() -> void:
	var table: LootTableData = _rewards.loot_table()
	var bonus: int = _rewards.loot_roll_bonus()
	var legendary_text: String = "%d+ Legendary" % table.legendary_from
	if _rewards.room_number < table.legendary_from_room:
		legendary_text += " (from room %d on)" % table.legendary_from_room
	_loot_info_label.text = (
		"Loot roll d%d%+d   ·   %d+ Uncommon   ·   %d+ Rare   ·   %s"
		% [LootRoll.DIE_SIDES, bonus, table.uncommon_from, table.rare_from, legendary_text]
	)
	_check_button.hide()
	_blood_price_button.visible = _rewards.is_blood_price_offered()
	if _rewards.is_blood_price_offered():
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
			% [rarity_text, _rewards.loot_table().legendary_from_room]
		)
	_find_label.add_theme_color_override("font_color", ItemSlot.RARITY_COLORS[loot.rarity])
	if loot.item == null:
		_find_label.text = "%s: %s" % [rarity_text, NOTHING_FOUND_TEXT]
		_find_details_label.text = ""
		_show_next_step()
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
	_leave_button.text = "Sell (+%d gold)" % _rewards.sell_value()
	_leave_button.show()


func _find_detail_lines(item: ItemData) -> Array[String]:
	var lines: Array[String] = [item.description]
	for change: StatSheet.Change in StatSheet.preview_item(RunState.player, item):
		lines.append("%s %s → %s" % [change.label, change.before, change.after])
	var worn: ItemData = RunState.player.item_in_slot(item.get_slot())
	if worn == null:
		lines.append("Your %s slot is empty." % ItemSlot.SLOT_NAMES[item.get_slot()].to_lower())
	else:
		lines.append("Replaces %s." % worn.display_name)
	return lines


func _on_take_pressed() -> void:
	_rewards.take_item()
	_find_details_label.text = "Equipped."
	_show_hit_points()
	_show_next_step()


func _on_leave_pressed() -> void:
	_find_details_label.text = "Sold for %d gold." % _rewards.sell_item()
	_show_gold()
	_show_next_step()


func _show_next_step() -> void:
	_take_button.hide()
	_leave_button.hide()
	_next_button.text = MapScreen.next_step_text()
	_next_button.show()
	_next_button.grab_focus()


func _on_next_pressed() -> void:
	# Disabled first, so a second press cannot leave the node twice.
	_next_button.disabled = true
	get_tree().change_scene_to_file(MapScreen.scene_after_node())
