class_name PaperDoll
extends HBoxContainer
## The character's pixel figure, the same as on the battlefield, with the equipment slots arranged
## around it.

const ITEM_SLOT_SCENE: PackedScene = preload("res://scenes/ui/item_slot.tscn")
## Every equipment slot in display order and the side of the figure it sits on. The equipment
## views build their slots from this, so a new ItemData.Slot needs no new nodes, only an entry
## here and its name and silhouette in ItemSlot.
const SLOT_SIDES: Dictionary[ItemData.Slot, Side] = {
	ItemData.Slot.WEAPON: SIDE_LEFT,
	ItemData.Slot.ARMOR: SIDE_RIGHT,
	ItemData.Slot.TALISMAN: SIDE_LEFT,
}
## The figure is larger than on the battlefield, so the sheet shows it in detail.
const FIGURE_SCALE: float = 2.0

var _item_slots: Dictionary[ItemData.Slot, ItemSlot] = {}

@onready var _left_slots: VBoxContainer = %LeftSlots
@onready var _right_slots: VBoxContainer = %RightSlots
@onready var _figure: FigureView = %Figure


func _ready() -> void:
	for slot: ItemData.Slot in SLOT_SIDES:
		var item_slot: ItemSlot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
		item_slot.show_item(slot, null)
		if SLOT_SIDES[slot] == SIDE_LEFT:
			_left_slots.add_child(item_slot)
		else:
			_right_slots.add_child(item_slot)
		_item_slots[slot] = item_slot


func show_character(character: Character) -> void:
	_figure.show_figure(character.class_data.figure_frames, false, FIGURE_SCALE)
	for slot: ItemData.Slot in SLOT_SIDES:
		_item_slots[slot].show_item(slot, character.item_in_slot(slot))


func item_slot(slot: ItemData.Slot) -> ItemSlot:
	return _item_slots[slot]


func figure() -> FigureView:
	return _figure
