class_name MerchantScreen
extends Control
## A merchant on the map: the node's level-up, items priced by rarity and healing for gold.

const ITEM_SLOT_SCENE: PackedScene = preload("res://scenes/ui/item_slot.tscn")
const OFFER_WIDTH: float = 260.0
const ITEM_NAME_FONT_SIZE: int = 18
const PRICE_COLOR: Color = Color(1.0, 0.82, 0.2)

var _stock: MerchantStock
var _buy_buttons: Dictionary[ItemData, Button] = {}
var _detail_labels: Dictionary[ItemData, Label] = {}

@onready var _level_up_label: Label = %LevelUpLabel
@onready var _status_label: Label = %StatusLabel
@onready var _offers: HBoxContainer = %Offers
@onready var _heal_label: Label = %HealLabel
@onready var _heal_button: Button = %HealButton
@onready var _leave_button: Button = %LeaveButton
@onready var _character_button: Button = %CharacterButton
@onready var _character_sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
	_heal_button.pressed.connect(buy_heal)
	_leave_button.pressed.connect(_on_leave_pressed)
	var rewards: RoomRewards = RunState.start_room_rewards()
	rewards.level_up()
	_level_up_label.text = LevelUp.level_up_text(rewards)
	_stock = RunState.create_merchant_stock()
	for item: ItemData in _stock.items:
		_offers.add_child(_create_offer(item))
	_refresh()
	_leave_button.grab_focus()


func offered_items() -> Array[ItemData]:
	var offered: Array[ItemData] = []
	offered.assign(_buy_buttons.keys())
	return offered


func buy(item: ItemData) -> void:
	if not _stock.can_buy(item, RunState.player):
		return
	_stock.buy(item, RunState.player)
	_buy_buttons[item].text = "Bought"
	_refresh()


func buy_heal() -> void:
	if not _stock.can_buy_heal(RunState.player):
		return
	_stock.buy_heal(RunState.player)
	_refresh()


func _create_offer(item: ItemData) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(OFFER_WIDTH, 0)
	var layout: VBoxContainer = VBoxContainer.new()
	card.add_child(layout)
	var slot: ItemSlot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
	layout.add_child(slot)
	slot.show_item(item.get_slot(), item)
	var name_label: Label = Label.new()
	name_label.text = "%s (%s)" % [item.display_name, ItemSlot.SLOT_NAMES[item.get_slot()]]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", ITEM_NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", ItemSlot.RARITY_COLORS[item.rarity])
	layout.add_child(name_label)
	var details: Label = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(details)
	_detail_labels[item] = details
	var button: Button = Button.new()
	button.text = "Buy · %d gold" % _stock.price_of(item)
	button.pressed.connect(buy.bind(item))
	layout.add_child(button)
	_buy_buttons[item] = button
	return card


func _refresh() -> void:
	var player: Character = RunState.player
	_status_label.text = (
		"HP %d / %d   ·   Gold %d" % [player.hit_points, player.max_hit_points, player.gold]
	)
	for item: ItemData in _buy_buttons:
		var is_sold: bool = not item in _stock.items
		_buy_buttons[item].disabled = is_sold or not _stock.can_buy(item, player)
		_detail_labels[item].text = "Bought." if is_sold else "\n".join(_offer_lines(item))
	var missing: int = player.max_hit_points - player.hit_points
	_heal_label.text = (
		"Healing: +%d HP (%d missing)" % [mini(_stock.heal_amount(player), missing), missing]
	)
	_heal_button.text = "Buy · %d gold" % _stock.heal_price()
	_heal_button.disabled = not _stock.can_buy_heal(player)


func _offer_lines(item: ItemData) -> Array[String]:
	var lines: Array[String] = [item.description]
	for change: StatSheet.Change in StatSheet.preview_item(RunState.player, item):
		lines.append("%s %s → %s" % [change.label, change.before, change.after])
	var worn: ItemData = RunState.player.item_in_slot(item.get_slot())
	if worn != null:
		lines.append("Replaces %s." % worn.display_name)
	return lines


func _on_leave_pressed() -> void:
	# Disabled first, so a second press cannot change the scene twice.
	_leave_button.disabled = true
	get_tree().change_scene_to_file(MapScreen.scene_after_node())
