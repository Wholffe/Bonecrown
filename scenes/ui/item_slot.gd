class_name ItemSlot
extends VBoxContainer
## One equipment slot: the item's icon in a frame of its rarity color, or the dimmed silhouette of
## the slot while it is empty. The tooltip names the item, its rarity, its slot and its effect.

## Emitted on a left click, so a screen can open more details from the slot.
signal clicked

## The post-fight screen and the character sheet use the names and colors too.
const RARITY_NAMES: Dictionary[ItemData.Rarity, String] = {
	ItemData.Rarity.COMMON: "Common",
	ItemData.Rarity.UNCOMMON: "Uncommon",
	ItemData.Rarity.RARE: "Rare",
	ItemData.Rarity.LEGENDARY: "Legendary",
}
const RARITY_COLORS: Dictionary[ItemData.Rarity, Color] = {
	ItemData.Rarity.COMMON: Color(0.8, 0.8, 0.82),
	ItemData.Rarity.UNCOMMON: Color(0.45, 0.85, 0.45),
	ItemData.Rarity.RARE: Color(0.45, 0.65, 1.0),
	ItemData.Rarity.LEGENDARY: Color(1.0, 0.6, 0.15),
}
const SLOT_NAMES: Dictionary[ItemData.Slot, String] = {
	ItemData.Slot.WEAPON: "Weapon",
	ItemData.Slot.ARMOR: "Armor",
	ItemData.Slot.TALISMAN: "Talisman",
}
const SLOT_SILHOUETTES: Dictionary[ItemData.Slot, Texture2D] = {
	ItemData.Slot.WEAPON: preload("res://assets/placeholder/slots/weapon.svg"),
	ItemData.Slot.ARMOR: preload("res://assets/placeholder/slots/armor.svg"),
	ItemData.Slot.TALISMAN: preload("res://assets/placeholder/slots/talisman.svg"),
}
const EMPTY_SLOT_TEXT: String = "(empty)"
## Starting items have no rarity, so their frame stays neutral.
const NEUTRAL_FRAME_COLOR: Color = Color(0.5, 0.5, 0.56)
const EMPTY_FRAME_COLOR: Color = Color(0.25, 0.25, 0.3)
const FRAME_BACKGROUND_COLOR: Color = Color(0.08, 0.08, 0.1)
const FRAME_WIDTH: int = 2
const FRAME_PADDING: int = 4
const FRAME_CORNER_RADIUS: int = 4
const SILHOUETTE_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.3)
const EMPTY_CAPTION_COLOR: Color = Color(0.55, 0.55, 0.6)
const TOOLTIP_TITLE_FONT_SIZE: int = 18

## Width and height of the icon inside the frame.
@export var icon_size: float = 48.0
## The caption under the frame names the item, or the slot while it is empty.
@export var caption_visible: bool = true

var slot: ItemData.Slot = ItemData.Slot.WEAPON
## Null while the slot is empty.
var item: ItemData
var _frame_style: StyleBoxFlat = _make_frame_style()

@onready var _frame: PanelContainer = %Frame
@onready var _icon: TextureRect = %Icon
@onready var _caption_label: Label = %CaptionLabel


func _ready() -> void:
	_frame.add_theme_stylebox_override("panel", _frame_style)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


# Godot frees the returned control when the tooltip closes.
func _make_custom_tooltip(_for_text: String) -> Object:
	var lines: VBoxContainer = VBoxContainer.new()
	var title: Label = _add_tooltip_line(
		lines, SLOT_NAMES[slot] if item == null else item.display_name
	)
	title.add_theme_font_size_override("font_size", TOOLTIP_TITLE_FONT_SIZE)
	if item == null:
		_add_tooltip_line(lines, EMPTY_SLOT_TEXT)
		return lines
	if RARITY_NAMES.has(item.rarity):
		var rarity_label: Label = _add_tooltip_line(lines, RARITY_NAMES[item.rarity])
		rarity_label.add_theme_color_override("font_color", RARITY_COLORS[item.rarity])
	_add_tooltip_line(lines, SLOT_NAMES[slot])
	if not item.description.is_empty():
		_add_tooltip_line(lines, item.description)
	return lines


## Shows the item, or the empty slot when the item is null. Works before and after _ready().
func show_item(shown_slot: ItemData.Slot, shown_item: ItemData) -> void:
	slot = shown_slot
	item = shown_item
	if is_node_ready():
		_refresh()


## The item's icon, or the slot's silhouette while it is empty.
func shown_icon() -> Texture2D:
	return _icon.texture


func frame_color() -> Color:
	return _frame_style.border_color


func is_dimmed() -> bool:
	return _icon.modulate == SILHOUETTE_MODULATE


func _refresh() -> void:
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_caption_label.visible = caption_visible
	if item == null:
		_icon.texture = SLOT_SILHOUETTES[slot]
		_icon.modulate = SILHOUETTE_MODULATE
		_frame_style.border_color = EMPTY_FRAME_COLOR
		_caption_label.text = SLOT_NAMES[slot]
		_caption_label.add_theme_color_override("font_color", EMPTY_CAPTION_COLOR)
	else:
		_icon.texture = item.icon
		_icon.modulate = Color.WHITE
		_frame_style.border_color = RARITY_COLORS.get(item.rarity, NEUTRAL_FRAME_COLOR)
		_caption_label.text = item.display_name
		_caption_label.remove_theme_color_override("font_color")
	# Godot only asks for the custom tooltip while the tooltip text is not empty.
	tooltip_text = _caption_label.text


func _add_tooltip_line(lines: VBoxContainer, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	lines.add_child(label)
	return label


func _make_frame_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FRAME_BACKGROUND_COLOR
	style.set_border_width_all(FRAME_WIDTH)
	style.set_corner_radius_all(FRAME_CORNER_RADIUS)
	style.set_content_margin_all(FRAME_PADDING)
	return style
