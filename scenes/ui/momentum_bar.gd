class_name MomentumBar
extends PanelContainer
## The player's Momentum as a row of large orbs. Previews what an action costs and animates changes.

const FILLED_COLOR: Color = Color(1.0, 0.78, 0.25)
const EMPTY_COLOR: Color = Color(0.22, 0.22, 0.27)
const PREVIEW_COLOR: Color = Color(1.0, 0.95, 0.75)
const BORDER_COLOR: Color = Color(0.45, 0.4, 0.3)
const GAIN_COLOR: Color = Color(1.0, 0.85, 0.35)
const LOSS_COLOR: Color = Color(0.85, 0.45, 0.4)
const ORB_SIZE: float = 34.0
const ORB_BORDER_WIDTH: int = 2
## Previewed orbs fade down to this alpha and back while the preview lasts.
const PREVIEW_PULSE_ALPHA: float = 0.35
const PREVIEW_PULSE_DURATION: float = 0.3
const POP_SCALE: float = 1.35
const POP_DURATION: float = 0.18
const CHANGE_LABEL_DURATION: float = 1.2

## Tests and a later fast mode turn the animations off.
var animations_enabled: bool = true
var _value: int = 0
var _cap: int = 0
var _preview_cost: int = 0
var _orb_styles: Array[StyleBoxFlat] = []
var _orb_faces: Array[Panel] = []
var _previewed_faces: Array[Panel] = []
var _pulse_tween: Tween
var _change_tween: Tween

@onready var _orbs: HBoxContainer = %Orbs
@onready var _count_label: Label = %CountLabel
@onready var _change_label: Label = %ChangeLabel


func show_momentum(value: int, cap: int) -> void:
	var gained_from: int = _value
	_value = value
	_cap = cap
	_rebuild_orbs()
	_count_label.text = "%d/%d" % [value, cap]
	_refresh_orbs()
	# Only gains pop; spent orbs simply go dark.
	if animations_enabled:
		for index: int in range(gained_from, value):
			_pop(_orb_faces[index])


## Shows a short note such as "+1 fended off" next to the orbs. It fades after a moment.
func show_change(change: int, reason_text: String) -> void:
	_change_label.text = "%+d %s" % [change, reason_text] if reason_text != "" else "%+d" % change
	_change_label.add_theme_color_override("font_color", GAIN_COLOR if change > 0 else LOSS_COLOR)
	_change_label.modulate.a = 1.0
	if _change_tween != null:
		_change_tween.kill()
	if animations_enabled:
		_change_tween = create_tween()
		_change_tween.tween_interval(CHANGE_LABEL_DURATION)
		_change_tween.tween_property(_change_label, "modulate:a", 0.0, POP_DURATION)


## Marks the filled orbs an action would spend. A cost of 0, or one that is not affordable,
## clears the preview.
func preview_cost(cost: int) -> void:
	_preview_cost = cost if cost <= _value else 0
	_refresh_orbs()


func shown_momentum() -> int:
	return _value


func previewed_orbs() -> int:
	return _preview_cost


func change_text() -> String:
	return _change_label.text


func _rebuild_orbs() -> void:
	while _orb_faces.size() > _cap:
		_orbs.get_child(-1).free()
		_orb_faces.pop_back()
		_orb_styles.pop_back()
	while _orb_faces.size() < _cap:
		# The face sits in a plain Control, because a container would reset its scale.
		var slot: Control = Control.new()
		slot.custom_minimum_size = Vector2(ORB_SIZE, ORB_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face: Panel = Panel.new()
		face.size = Vector2(ORB_SIZE, ORB_SIZE)
		face.pivot_offset = face.size / 2.0
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(roundi(ORB_SIZE / 2.0))
		style.border_color = BORDER_COLOR
		style.set_border_width_all(ORB_BORDER_WIDTH)
		face.add_theme_stylebox_override("panel", style)
		slot.add_child(face)
		_orbs.add_child(slot)
		_orb_faces.append(face)
		_orb_styles.append(style)


func _refresh_orbs() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	var first_previewed: int = _value - _preview_cost
	_previewed_faces.clear()
	for index: int in _orb_faces.size():
		var style: StyleBoxFlat = _orb_styles[index]
		_orb_faces[index].modulate.a = 1.0
		if index >= _value:
			style.bg_color = EMPTY_COLOR
		elif index >= first_previewed:
			style.bg_color = PREVIEW_COLOR
			_previewed_faces.append(_orb_faces[index])
		else:
			style.bg_color = FILLED_COLOR
	if _previewed_faces.is_empty() or not animations_enabled:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_preview_alpha, 1.0, PREVIEW_PULSE_ALPHA, PREVIEW_PULSE_DURATION)
	_pulse_tween.tween_method(_set_preview_alpha, PREVIEW_PULSE_ALPHA, 1.0, PREVIEW_PULSE_DURATION)


func _set_preview_alpha(alpha: float) -> void:
	for face: Panel in _previewed_faces:
		face.modulate.a = alpha


func _pop(face: Panel) -> void:
	face.scale = Vector2(POP_SCALE, POP_SCALE)
	var tween: Tween = create_tween()
	tween.tween_property(face, "scale", Vector2.ONE, POP_DURATION)
