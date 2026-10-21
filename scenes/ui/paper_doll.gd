class_name PaperDoll
extends HBoxContainer
## The character's figure in the worn gear, with the equipment slots arranged around it.

const ITEM_SLOT_SCENE: PackedScene = preload("res://scenes/ui/item_slot.tscn")
## Every equipment slot in display order and the side of the figure it sits on. The equipment
## views build their slots from this, so a new ItemData.Slot needs no new nodes, only an entry
## here and its name and silhouette in ItemSlot. The figure layers stack in this order too.
const SLOT_SIDES: Dictionary[ItemData.Slot, Side] = {
	ItemData.Slot.WEAPON: SIDE_LEFT,
	ItemData.Slot.ARMOR: SIDE_RIGHT,
	ItemData.Slot.TALISMAN: SIDE_LEFT,
}

var _item_slots: Dictionary[ItemData.Slot, ItemSlot] = {}

@onready var _left_slots: VBoxContainer = %LeftSlots
@onready var _right_slots: VBoxContainer = %RightSlots
@onready var _layers: Control = %Layers


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
	_clear_layers()
	for slot: ItemData.Slot in SLOT_SIDES:
		var item: ItemData = character.item_in_slot(slot)
		_item_slots[slot].show_item(slot, item)
		if item != null and item.figure_layer != null:
			_layers.add_child(_create_layer(item.figure_layer))


func item_slot(slot: ItemData.Slot) -> ItemSlot:
	return _item_slots[slot]


## The textures drawn over the body, the lowest first.
func figure_layers() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for layer: Node in _layers.get_children():
		textures.append((layer as TextureRect).texture)
	return textures


# free() instead of queue_free(), so the figure is complete again within the same frame.
func _clear_layers() -> void:
	for layer: Node in _layers.get_children():
		_layers.remove_child(layer)
		layer.free()


# Every figure layer shares the body's canvas, so a full-rect layer lines up with the body.
func _create_layer(texture: Texture2D) -> TextureRect:
	var layer: TextureRect = TextureRect.new()
	layer.texture = texture
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer
