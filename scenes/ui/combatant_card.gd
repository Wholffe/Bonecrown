class_name CombatantCard
extends PanelContainer
## Placeholder portrait of one combatant with hit points and stats. Enemy cards can be marked.

signal selected(card: CombatantCard)

const PLAYER_BODY_COLOR: Color = Color(0.25, 0.45, 0.85)
const ENEMY_BODY_COLOR: Color = Color(0.75, 0.3, 0.25)
const BACKGROUND_COLOR: Color = Color(0.13, 0.13, 0.16)
const BORDER_COLOR: Color = Color(0.32, 0.32, 0.38)
const SELECTED_BORDER_COLOR: Color = Color(1.0, 0.82, 0.2)
const BORDER_WIDTH: int = 2
const SELECTED_BORDER_WIDTH: int = 4
const PADDING: int = 12
const DEFEATED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.35)

var combatant: Combatant
var _shown_hit_points: int = 0
var _is_selectable: bool = false
var _is_selected: bool = false
var _normal_style: StyleBoxFlat = _make_style(BORDER_COLOR, BORDER_WIDTH)
var _selected_style: StyleBoxFlat = _make_style(SELECTED_BORDER_COLOR, SELECTED_BORDER_WIDTH)

@onready var _body: ColorRect = %Body
@onready var _name_label: Label = %NameLabel
@onready var _hit_point_bar: ProgressBar = %HitPointBar
@onready var _hit_point_label: Label = %HitPointLabel
@onready var _stats_label: Label = %StatsLabel


func _ready() -> void:
	_refresh_look()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _can_be_selected():
		accept_event()
		selected.emit(self)


func show_combatant(shown_combatant: Combatant, is_player: bool) -> void:
	combatant = shown_combatant
	_body.color = PLAYER_BODY_COLOR if is_player else ENEMY_BODY_COLOR
	_name_label.text = shown_combatant.display_name
	_stats_label.text = (
		"AC %d   Attack %+d"
		% [shown_combatant.get_armor_class(), shown_combatant.get_attack_bonus()]
	)
	_hit_point_bar.max_value = shown_combatant.max_hit_points
	show_hit_points(shown_combatant.hit_points)


## Takes an explicit value, so the battle playback can show hit points from before later events.
func show_hit_points(value: int) -> void:
	_shown_hit_points = value
	_hit_point_bar.value = value
	_hit_point_label.text = "HP %d/%d" % [value, combatant.max_hit_points]
	_refresh_look()


func is_defeated() -> bool:
	return _shown_hit_points <= 0


func set_selectable(value: bool) -> void:
	_is_selectable = value
	_refresh_look()


func is_selectable() -> bool:
	return _is_selectable


func set_selected(value: bool) -> void:
	_is_selected = value
	_refresh_look()


func is_selected() -> bool:
	return _is_selected


func _can_be_selected() -> bool:
	return _is_selectable and combatant != null and not is_defeated()


func _refresh_look() -> void:
	add_theme_stylebox_override("panel", _selected_style if _is_selected else _normal_style)
	modulate = DEFEATED_MODULATE if combatant != null and is_defeated() else Color.WHITE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if _can_be_selected() else CURSOR_ARROW


func _make_style(border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BACKGROUND_COLOR
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_content_margin_all(PADDING)
	return style
