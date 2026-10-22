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
const MOMENTUM_PIP_SIZE: Vector2 = Vector2(12, 12)
const MOMENTUM_FILLED_COLOR: Color = Color(1.0, 0.78, 0.25)
const MOMENTUM_EMPTY_COLOR: Color = Color(0.25, 0.25, 0.3)
const INTENT_COLOR: Color = Color(0.85, 0.85, 0.9)
## Intents that cost Momentum are the enemy's big moves, so they stand out.
const SPECIAL_INTENT_COLOR: Color = Color(1.0, 0.5, 0.35)

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
@onready var _roll_mode_label: Label = %RollModeLabel
@onready var _momentum_pips: HBoxContainer = %MomentumPips
@onready var _intent_label: Label = %IntentLabel


func _ready() -> void:
	_refresh_look()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _can_be_selected():
		accept_event()
		selected.emit(self)


## For example "Frenzy: 2× 1d6+1" or "Chill Strike: 1d6+2, −1 Momentum on a hit".
static func describe_intent(enemy: Enemy, intent: EnemyIntentData) -> String:
	var dice: String = StatSheet.dice_text(
		enemy.get_damage_die_count() + intent.extra_damage_dice,
		enemy.get_damage_die_sides(),
		enemy.get_damage_bonus()
	)
	if intent.attack_count > 1:
		dice = "%d× %s" % [intent.attack_count, dice]
	var parts: PackedStringArray = []
	# An intent without attacks, such as a boss's Command, only shows its other effects.
	if intent.attack_count > 0:
		parts.append(dice)
	if intent.momentum_drain > 0:
		parts.append("−%d Momentum on a hit" % intent.momentum_drain)
	if intent.momentum_to_allies > 0:
		parts.append("allies +%d Momentum" % intent.momentum_to_allies)
	return "%s: %s" % [intent.display_name, ", ".join(parts)]


func show_combatant(shown_combatant: Combatant, is_player: bool) -> void:
	combatant = shown_combatant
	_body.color = PLAYER_BODY_COLOR if is_player else ENEMY_BODY_COLOR
	_name_label.text = shown_combatant.display_name
	show_stats(shown_combatant.get_armor_class(), shown_combatant.get_attack_bonus())
	_hit_point_bar.max_value = shown_combatant.max_hit_points
	show_hit_points(shown_combatant.hit_points)


## Takes explicit values, because a boss phase changes them during the battle playback.
func show_stats(armor_class: int, attack_bonus: int) -> void:
	_stats_label.text = "AC %d   Attack %+d" % [armor_class, attack_bonus]


## Takes an explicit value, so the battle playback can show hit points from before later events.
func show_hit_points(value: int) -> void:
	_shown_hit_points = value
	_hit_point_bar.value = value
	_hit_point_label.text = "HP %d/%d" % [value, combatant.max_hit_points]
	_refresh_look()


func show_momentum(value: int, cap: int) -> void:
	# The pips are kept and only recolored, because the value changes many times per round.
	while _momentum_pips.get_child_count() > cap:
		_momentum_pips.get_child(-1).free()
	while _momentum_pips.get_child_count() < cap:
		var new_pip: ColorRect = ColorRect.new()
		new_pip.custom_minimum_size = MOMENTUM_PIP_SIZE
		new_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_momentum_pips.add_child(new_pip)
	for index: int in cap:
		var pip: ColorRect = _momentum_pips.get_child(index) as ColorRect
		pip.color = MOMENTUM_FILLED_COLOR if index < value else MOMENTUM_EMPTY_COLOR
	_momentum_pips.tooltip_text = "Momentum %d/%d" % [value, cap]


## Number of filled Momentum pips, for tests and later effects.
func shown_momentum() -> int:
	var filled: int = 0
	for pip: Node in _momentum_pips.get_children():
		if (pip as ColorRect).color == MOMENTUM_FILLED_COLOR:
			filled += 1
	return filled


## Shows what the enemy will do on its turn. A null intent hides the line.
func show_intent(intent: EnemyIntentData) -> void:
	_intent_label.visible = intent != null and combatant.is_alive()
	if not _intent_label.visible:
		return
	_intent_label.text = "Next: " + describe_intent(combatant as Enemy, intent)
	_intent_label.add_theme_color_override(
		"font_color", SPECIAL_INTENT_COLOR if intent.momentum_cost > 0 else INTENT_COLOR
	)


func intent_text() -> String:
	return _intent_label.text if _intent_label.visible else ""


## Tags the card while the combatant's next attack roll has advantage or disadvantage.
func show_roll_mode(mode: AttackRoll.RollMode) -> void:
	_roll_mode_label.visible = mode != AttackRoll.RollMode.NORMAL
	if _roll_mode_label.visible:
		_roll_mode_label.text = DiceDisplay.ROLL_MODE_TEXTS[mode]
		_roll_mode_label.add_theme_color_override("font_color", DiceDisplay.ROLL_MODE_COLORS[mode])


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
