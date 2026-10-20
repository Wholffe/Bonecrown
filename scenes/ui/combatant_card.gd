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
const UNKNOWN_ATTACK_BONUS_TEXT: String = "Attack ?"

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


func _ready() -> void:
	_refresh_look()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _can_be_selected():
		accept_event()
		selected.emit(self)


## Armor class as far as the rolls so far prove it: "AC ?", "AC ≥ 13", "AC ≤ 15", "AC 13–15" or
## the exact "AC 14". Either bound may be EnemyKnowledge.UNKNOWN. A known value is passed as both.
static func describe_armor_class(lowest: int, highest: int) -> String:
	if lowest == EnemyKnowledge.UNKNOWN and highest == EnemyKnowledge.UNKNOWN:
		return "AC ?"
	if highest == EnemyKnowledge.UNKNOWN:
		return "AC ≥ %d" % lowest
	if lowest == EnemyKnowledge.UNKNOWN:
		return "AC ≤ %d" % highest
	if lowest == highest:
		return "AC %d" % lowest
	return "AC %d–%d" % [lowest, highest]


## The player's stats are shown exactly. Enemy stats stay hidden until show_enemy_knowledge().
func show_combatant(shown_combatant: Combatant, is_player: bool) -> void:
	combatant = shown_combatant
	_body.color = PLAYER_BODY_COLOR if is_player else ENEMY_BODY_COLOR
	_name_label.text = shown_combatant.display_name
	if is_player:
		var armor_class: int = shown_combatant.get_armor_class()
		_show_stats(
			describe_armor_class(armor_class, armor_class),
			"Attack %+d" % shown_combatant.get_attack_bonus()
		)
	else:
		_show_stats(
			describe_armor_class(EnemyKnowledge.UNKNOWN, EnemyKnowledge.UNKNOWN),
			UNKNOWN_ATTACK_BONUS_TEXT
		)
	_hit_point_bar.max_value = shown_combatant.max_hit_points
	show_hit_points(shown_combatant.hit_points)


## Shows what the player has learned about the type of this enemy so far.
func show_enemy_knowledge(knowledge: EnemyKnowledge) -> void:
	var enemy_id: StringName = (combatant as Enemy).data.id
	var attack_bonus_text: String = UNKNOWN_ATTACK_BONUS_TEXT
	if knowledge.is_attack_bonus_known(enemy_id):
		attack_bonus_text = "Attack %+d" % knowledge.attack_bonus(enemy_id)
	_show_stats(
		describe_armor_class(
			knowledge.lowest_armor_class(enemy_id), knowledge.highest_armor_class(enemy_id)
		),
		attack_bonus_text
	)


## Takes an explicit value, so the battle playback can show hit points from before later events.
func show_hit_points(value: int) -> void:
	_shown_hit_points = value
	_hit_point_bar.value = value
	_hit_point_label.text = "HP %d/%d" % [value, combatant.max_hit_points]
	_refresh_look()


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


func _show_stats(armor_class_text: String, attack_bonus_text: String) -> void:
	_stats_label.text = "%s   %s" % [armor_class_text, attack_bonus_text]


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
