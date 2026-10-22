class_name Battle
extends Control
## Battle screen with combatant cards, dice display, combat log and action bar.

## Emitted after all queued combat events have been shown.
signal playback_finished

const COMBATANT_CARD_SCENE: PackedScene = preload("res://scenes/ui/combatant_card.tscn")
const ITEM_SLOT_SCENE: PackedScene = preload("res://scenes/ui/item_slot.tscn")
const EQUIPMENT_ICON_SIZE: float = 36.0
# A preload would form a cycle, because the main menu preloads this scene.
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"
# The post-fight screen leads back here, so a preload would form a cycle too.
const LEVEL_UP_SCENE_PATH: String = "res://scenes/levelup/level_up.tscn"
# The run end screen starts new runs here.
const RUN_END_SCENE_PATH: String = "res://scenes/run_end/run_end.tscn"
## The layout steps through these offsets when a crit is revealed, then returns to its rest.
const SHAKE_OFFSETS: Array[Vector2] = [
	Vector2(10, -6), Vector2(-9, 5), Vector2(7, 4), Vector2(-5, -3), Vector2(2, 2)
]
const SHAKE_STEP_DURATION: float = 0.035
## Momentum changes worth a log line. Spending and the gain of a new round show only on the pips.
const MOMENTUM_REASON_TEXTS: Dictionary[Combat.MomentumReason, String] = {
	Combat.MomentumReason.FENDED_OFF: "attack fended off",
	Combat.MomentumReason.KILL: "kill",
	Combat.MomentumReason.DRAINED: "drained",
	Combat.MomentumReason.RALLIED: "rallied",
}
## Short notes next to the Momentum bar. Spending shows the change only.
const MOMENTUM_BAR_NOTES: Dictionary[Combat.MomentumReason, String] = {
	Combat.MomentumReason.NEW_ROUND: "new round",
	Combat.MomentumReason.FENDED_OFF: "fended off",
	Combat.MomentumReason.KILL: "kill",
	Combat.MomentumReason.DRAINED: "drained",
}
const OUT_OF_MOMENTUM_LOG: String = "Out of Momentum – your turn ends."
const END_TURN_HIGHLIGHT_COLOR: Color = Color(1.0, 0.78, 0.25)
const END_TURN_HIGHLIGHT_BORDER_WIDTH: int = 3

var _combat: Combat
var _cards: Dictionary[Combatant, CombatantCard] = {}
var _enemy_cards: Array[CombatantCard] = []
var _target_card: CombatantCard
var _skill_buttons: Dictionary[SkillData, Button] = {}
# Combat resolves a whole turn at once, so its signals queue events that are played back in order.
var _pending_events: Array[Callable] = []
var _is_playing_back: bool = false
# Kept here, because tests set it before _ready(), when the dice display does not exist yet.
var _animations_enabled: bool = true
var _shake_tween: Tween
var _layout_rest_position: Vector2 = Vector2.ZERO
# Set while the End Turn button ends the turn, so the playback can tell it from an automatic end.
var _is_ending_turn_by_hand: bool = false
var _is_end_turn_highlighted: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _popup_layer: PopupLayer = %PopupLayer
@onready var _player_card: CombatantCard = %PlayerCard
@onready var _equipment_strip: HBoxContainer = %EquipmentStrip
@onready var _player_level_label: Label = %PlayerLevelLabel
@onready var _player_skills_label: Label = %PlayerSkillsLabel
@onready var _enemy_cards_box: HBoxContainer = %EnemyCards
@onready var _dice_display: DiceDisplay = %DiceDisplay
@onready var _combat_log: RichTextLabel = %CombatLog
@onready var _attack_button: Button = %AttackButton
@onready var _block_button: Button = %BlockButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _skill_buttons_box: VBoxContainer = %SkillButtons
@onready var _character_button: Button = %CharacterButton
@onready var _continue_button: Button = %ContinueButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _character_sheet: CharacterSheet = %CharacterSheet
@onready var _momentum_bar: MomentumBar = %MomentumBar
@onready var _turn_banner: TurnBanner = %TurnBanner


func _ready() -> void:
	_apply_animations_enabled()
	_attack_button.pressed.connect(_on_attack_button_pressed)
	_block_button.pressed.connect(_on_block_button_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	_continue_button.pressed.connect(_on_continue_button_pressed)
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
	_character_sheet.visibility_changed.connect(_on_character_sheet_visibility_changed)
	_create_equipment_strip()
	_start_combat()


func is_playing_back() -> bool:
	return _is_playing_back


## Returns at once when nothing plays back, because playback_finished is emitted synchronously
## when no event animates, so awaiting the signal itself could wait forever.
func wait_for_playback() -> void:
	if _is_playing_back:
		await playback_finished
		# Resuming inside the emit would keep this node locked, so freeing it right after would fail.
		await get_tree().process_frame


## Where Continue leads once the fight is over: after a won fight before the boss room the
## post-fight screen follows, after the boss fight or a death the run end screen.
func next_scene_path() -> String:
	if _combat.player.is_alive() and not RunState.is_boss_room():
		return LEVEL_UP_SCENE_PATH
	return RUN_END_SCENE_PATH


## Tests and a later fast mode turn the roll animation off. Works before and after _ready().
func set_animations_enabled(enabled: bool) -> void:
	_animations_enabled = enabled
	if is_node_ready():
		_apply_animations_enabled()


## Whether End Turn glows because it is the obvious next action.
func is_end_turn_highlighted() -> bool:
	return _is_end_turn_highlighted


func _apply_animations_enabled() -> void:
	_dice_display.animations_enabled = _animations_enabled
	_momentum_bar.animations_enabled = _animations_enabled
	_turn_banner.animations_enabled = _animations_enabled


# The equipment cannot change during a fight, so the strip is built once.
func _create_equipment_strip() -> void:
	for slot: ItemData.Slot in PaperDoll.SLOT_SIDES:
		var item_slot: ItemSlot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
		item_slot.icon_size = EQUIPMENT_ICON_SIZE
		item_slot.caption_visible = false
		item_slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item_slot.show_item(slot, RunState.player.item_in_slot(slot))
		item_slot.clicked.connect(_character_sheet.open)
		_equipment_strip.add_child(item_slot)


func _start_combat() -> void:
	var enemies: Array[Combatant] = RunState.create_room_enemies()
	_combat = Combat.new(RunState.player, enemies, RunState.dice, RunState.GAME_RULES)
	_combat.round_started.connect(_on_round_started)
	_combat.attack_resolved.connect(_on_attack_resolved)
	_combat.skill_used.connect(_on_skill_used)
	_combat.combatant_healed.connect(_on_combatant_healed)
	_combat.attacker_drained.connect(_on_attacker_drained)
	_combat.combatant_defeated.connect(_on_combatant_defeated)
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.momentum_changed.connect(_on_momentum_changed)
	_combat.intents_announced.connect(_on_intents_announced)
	_combat.player_blocked.connect(_on_player_blocked)
	_combat.intent_started.connect(_on_intent_started)
	_combat.phase_started.connect(_on_phase_started)
	_combat.enemy_summoned.connect(_on_enemy_summoned)
	_combat.player_turn_ended.connect(_on_player_turn_ended)
	_create_cards(enemies)
	_create_action_buttons()
	_log("Room %d   ·   Run seed: %d" % [RunState.room_number, RunState.run_seed])
	for enemy: Combatant in enemies:
		_log("A %s appears." % enemy.display_name)
	_select_target(_first_living_card())
	_combat.start()
	_play_pending_events()


func _create_cards(enemies: Array[Combatant]) -> void:
	var player: Combatant = _combat.player
	_player_card.show_combatant(player, true)
	_player_card.set_momentum_visible(false)
	_momentum_bar.show_momentum(0, RunState.GAME_RULES.momentum_cap)
	_cards[player] = _player_card
	for enemy: Combatant in enemies:
		_add_enemy_card(enemy as Enemy)


func _add_enemy_card(enemy: Enemy) -> void:
	var card: CombatantCard = COMBATANT_CARD_SCENE.instantiate() as CombatantCard
	_enemy_cards_box.add_child(card)
	card.show_combatant(enemy, false)
	card.show_momentum(enemy.momentum, enemy.momentum_cap())
	card.selected.connect(_on_enemy_card_selected)
	_cards[enemy] = card
	_enemy_cards.append(card)


func _create_action_buttons() -> void:
	var rules: GameRulesData = RunState.GAME_RULES
	_attack_button.text = "Attack · %d" % rules.attack_momentum_cost
	_attack_button.tooltip_text = _describe_cost(rules.attack_momentum_cost)
	_connect_cost_preview(_attack_button, rules.attack_momentum_cost)
	_connect_cost_preview(_block_button, rules.block_momentum_cost)
	_block_button.text = "Block · %d" % rules.block_momentum_cost
	_block_button.tooltip_text = (
		"Enemy attacks roll with disadvantage until your next turn.\n"
		+ _describe_cost(rules.block_momentum_cost)
	)
	_end_turn_button.tooltip_text = ("Unused Momentum carries over, up to %d." % rules.momentum_cap)
	for skill: SkillData in _combat.player.active_skills():
		var button: Button = Button.new()
		button.name = skill.id.to_pascal_case() + "Button"
		button.tooltip_text = "%s\n%s" % [skill.description, _describe_cost(skill.momentum_cost)]
		button.pressed.connect(_on_skill_button_pressed.bind(skill))
		_connect_cost_preview(button, skill.momentum_cost)
		_skill_buttons_box.add_child(button)
		_skill_buttons[skill] = button


# Hovering an action makes the orbs it would spend pulse on the Momentum bar.
func _connect_cost_preview(button: Button, momentum_cost: int) -> void:
	button.mouse_entered.connect(_preview_cost.bind(button, momentum_cost))
	button.mouse_exited.connect(_momentum_bar.preview_cost.bind(0))


func _preview_cost(button: Button, momentum_cost: int) -> void:
	_momentum_bar.preview_cost(0 if button.disabled else momentum_cost)


func _select_target(card: CombatantCard) -> void:
	_target_card = card
	for enemy_card: CombatantCard in _enemy_cards:
		enemy_card.set_selected(enemy_card == card)


func _first_living_card() -> CombatantCard:
	for card: CombatantCard in _enemy_cards:
		if not card.is_defeated():
			return card
	return null


## Looks at the cards after the given one first and wraps around at the end.
func _next_living_card(after: CombatantCard) -> CombatantCard:
	var start: int = _enemy_cards.find(after)
	for offset: int in range(1, _enemy_cards.size()):
		var card: CombatantCard = _enemy_cards[(start + offset) % _enemy_cards.size()]
		if not card.is_defeated():
			return card
	return null


func _play_pending_events() -> void:
	if _is_playing_back:
		return
	_is_playing_back = true
	# The sheet would show values from after the turn while the turn still plays back.
	_character_sheet.hide()
	_refresh_actions()
	while not _pending_events.is_empty():
		var event: Callable = _pending_events.pop_front()
		await event.call()
	_is_playing_back = false
	_refresh_actions()
	_refresh_player_info()
	_refresh_roll_modes()
	_focus_default_action()
	playback_finished.emit()


func _focus_default_action() -> void:
	if _continue_button.visible:
		_continue_button.grab_focus()
	elif _combat.is_over:
		_main_menu_button.grab_focus()
	elif not _attack_button.disabled:
		_attack_button.grab_focus()
	else:
		_end_turn_button.grab_focus()


func _play_round_start(round_number: int) -> void:
	_log("")
	_log("Round %d" % round_number)
	# Not awaited: the player may act while it fades. Only the way into the enemy turn pauses.
	_turn_banner.play(TurnBanner.YOUR_TURN_TEXT, TurnBanner.YOUR_TURN_COLOR)


func _play_turn_end(by_hand: bool) -> void:
	_momentum_bar.preview_cost(0)
	if not by_hand:
		_log(OUT_OF_MOMENTUM_LOG)
		await _turn_banner.play(TurnBanner.OUT_OF_MOMENTUM_TEXT, TurnBanner.OUT_OF_MOMENTUM_COLOR)
	_log("Enemy turn")
	await _turn_banner.play(TurnBanner.ENEMY_TURN_TEXT, TurnBanner.ENEMY_TURN_COLOR)


func _play_attack(
	attacker: Combatant,
	defender: Combatant,
	attack: AttackRoll,
	damage: DamageRoll,
	defender_hit_points: int
) -> void:
	var armor_class_text: String = "AC %d" % attack.target_armor_class
	await _dice_display.play_attack(attacker, defender, attack, damage, armor_class_text)
	_log(_describe_attack(attacker, defender, attack, damage, armor_class_text))
	if attack.is_natural_one:
		_log("Natural 1 – Off-Balance: next attack with disadvantage")
	_cards[defender].show_hit_points(defender_hit_points)
	if _animations_enabled:
		_show_attack_feedback(attacker, _cards[defender], attack, damage)
	await _dice_display.hold()


func _play_heal(
	combatant: Combatant, skill: SkillData, heal: HealRoll, restored: int, hit_points: int
) -> void:
	await _dice_display.play_heal(_describe_heal_title(combatant, skill), heal, restored)
	_log(_describe_heal(combatant, heal, restored))
	_cards[combatant].show_hit_points(hit_points)
	if _animations_enabled:
		_popup_layer.show_heal(_cards[combatant], restored)
	await _dice_display.hold()


func _play_drain(attacker: Combatant, restored: int, hit_points: int) -> void:
	_log("Natural 20 – Crit + Drain: +%d HP" % restored)
	_cards[attacker].show_hit_points(hit_points)
	if _animations_enabled:
		_popup_layer.show_heal(_cards[attacker], restored)
	await _dice_display.hold()


func _show_attack_feedback(
	attacker: Combatant, defender_card: CombatantCard, attack: AttackRoll, damage: DamageRoll
) -> void:
	var outcome: DiceDisplay.Outcome = DiceDisplay.outcome_for(attack)
	_popup_layer.show_attack(defender_card, outcome, damage, attacker.get_damage_die_sides())
	if outcome == DiceDisplay.Outcome.CRITICAL_HIT:
		_shake_layout()


# The margin's parent is no container, so nothing resets its position while it shakes.
func _shake_layout() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
		_margin.position = _layout_rest_position
	_layout_rest_position = _margin.position
	_shake_tween = create_tween()
	for offset: Vector2 in SHAKE_OFFSETS:
		_shake_tween.tween_property(
			_margin, "position", _layout_rest_position + offset, SHAKE_STEP_DURATION
		)
	_shake_tween.tween_property(_margin, "position", _layout_rest_position, SHAKE_STEP_DURATION)


func _play_momentum_change(
	combatant: Combatant, momentum: int, cap: int, change: int, reason: Combat.MomentumReason
) -> void:
	if combatant == _combat.player:
		_momentum_bar.show_momentum(momentum, cap)
		_momentum_bar.show_change(change, MOMENTUM_BAR_NOTES.get(reason, ""))
	else:
		_cards[combatant].show_momentum(momentum, cap)
	var reason_text: String = MOMENTUM_REASON_TEXTS.get(reason, "")
	if reason_text != "":
		_log("%s %+d Momentum (%s)" % [combatant.display_name, change, reason_text])


func _play_intents(intents: Dictionary[Enemy, EnemyIntentData]) -> void:
	for enemy: Enemy in intents:
		_cards[enemy].show_intent(intents[enemy])


func _play_intent_start(enemy: Enemy, intent: EnemyIntentData) -> void:
	_log("%s uses %s." % [enemy.display_name, intent.display_name])
	_cards[enemy].show_intent(null)


func _play_phase_start(
	boss: Enemy, phase: BossPhaseData, armor_class: int, momentum: int, momentum_cap: int
) -> void:
	_log(phase.announcement)
	var card: CombatantCard = _cards[boss]
	card.show_stats(armor_class, boss.get_attack_bonus())
	card.show_momentum(momentum, momentum_cap)
	if _animations_enabled:
		_shake_layout()
	await _dice_display.hold()


func _play_summon(summon: Enemy) -> void:
	_add_enemy_card(summon)
	_log("A %s appears." % summon.display_name)
	await _dice_display.hold()


func _play_defeat(combatant: Combatant) -> void:
	_log("%s is defeated." % combatant.display_name)
	# A summon falls with its summoner without an attack that showed its hit points.
	_cards[combatant].show_hit_points(0)
	var enemy: Enemy = combatant as Enemy
	if enemy != null:
		_cards[enemy].show_intent(null)
	if _cards[combatant] == _target_card:
		_select_target(_next_living_card(_target_card))


func _play_combat_end(player_won: bool) -> void:
	_log("")
	_log("Victory!" if player_won else "You have fallen. The run is over.")
	_continue_button.visible = true


# The input handlers check this too, because a scripted pressed.emit() ignores disabled buttons.
func _can_act() -> bool:
	return not _is_playing_back and not _combat.is_over and not _character_sheet.visible


func _can_attack() -> bool:
	return (
		_can_act()
		and _combat.can_attack()
		and _target_card != null
		and _target_card.combatant.is_alive()
	)


func _refresh_actions() -> void:
	var can_act: bool = _can_act()
	_attack_button.disabled = not _can_attack()
	_block_button.disabled = not can_act or not _combat.can_block()
	_end_turn_button.disabled = not can_act
	_character_button.disabled = _is_playing_back
	_character_sheet.is_locked = _is_playing_back
	for skill: SkillData in _skill_buttons:
		var button: Button = _skill_buttons[skill]
		button.text = _describe_skill_button(skill)
		button.disabled = not can_act or not _combat.can_use_skill(skill)
	_main_menu_button.disabled = _is_playing_back
	_continue_button.disabled = _is_playing_back
	# Without enough Momentum to attack, ending the turn is usually what is left to do.
	_set_end_turn_highlight(can_act and not _combat.can_attack())
	for card: CombatantCard in _enemy_cards:
		card.set_selectable(can_act)


func _set_end_turn_highlight(value: bool) -> void:
	_is_end_turn_highlighted = value
	if not value:
		_end_turn_button.remove_theme_color_override("font_color")
		_end_turn_button.remove_theme_stylebox_override("normal")
		return
	var style: StyleBoxFlat = _end_turn_button.get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		style = style.duplicate() as StyleBoxFlat
		style.border_color = END_TURN_HIGHLIGHT_COLOR
		style.set_border_width_all(END_TURN_HIGHLIGHT_BORDER_WIDTH)
		_end_turn_button.add_theme_stylebox_override("normal", style)
	_end_turn_button.add_theme_color_override("font_color", END_TURN_HIGHLIGHT_COLOR)


func _refresh_player_info() -> void:
	_player_level_label.text = "Level %d" % _combat.player.level
	var lines: PackedStringArray = ["Skills:"]
	for skill: SkillData in _combat.player.skills:
		var uses: int = _combat.uses_left(skill)
		if uses == Combat.UNLIMITED_USES:
			lines.append(skill.display_name)
		else:
			lines.append("%s (%d left)" % [skill.display_name, uses])
	_player_skills_label.text = "\n".join(lines)


# Off-Balance ends with the fight, and a defeated enemy never attacks again.
func _refresh_roll_modes() -> void:
	for combatant: Combatant in _cards:
		var mode: AttackRoll.RollMode = AttackRoll.RollMode.NORMAL
		if not _combat.is_over and combatant.is_alive():
			mode = _combat.next_roll_mode(combatant)
		_cards[combatant].show_roll_mode(mode)


func _describe_cost(momentum_cost: int) -> String:
	return "Costs %d Momentum." % momentum_cost


func _describe_skill_button(skill: SkillData) -> String:
	var text: String = "%s · %d" % [skill.display_name, skill.momentum_cost]
	var uses: int = _combat.uses_left(skill)
	if uses == Combat.UNLIMITED_USES:
		return text
	return "%s  (%d left)" % [text, uses]


func _describe_attack(
	attacker: Combatant,
	defender: Combatant,
	attack: AttackRoll,
	damage: DamageRoll,
	armor_class_text: String
) -> String:
	var roll_text: String = (
		"%s attacks %s: %s %+d = %d vs %s"
		% [
			attacker.display_name,
			defender.display_name,
			_describe_d20(attack),
			attack.attack_bonus,
			attack.total,
			armor_class_text,
		]
	)
	if attack.is_natural_one:
		return roll_text + " - natural 1, automatic miss."
	if not attack.is_hit:
		return roll_text + " - miss."
	var hit_text: String = "hit,"
	if attack.is_crit:
		hit_text = "critical hit!"
	elif attack.is_narrow_hit:
		hit_text = "narrow hit,"
	return roll_text + " - %s %d damage (%s)." % [hit_text, damage.total, _describe_damage(damage)]


# The kept d20 comes first, for example "d20 15 / 4 (advantage)".
func _describe_d20(attack: AttackRoll) -> String:
	if attack.roll_mode == AttackRoll.RollMode.NORMAL:
		return "d20 %d" % attack.natural_roll
	return (
		"d20 %d / %d (%s)"
		% [
			attack.natural_roll,
			attack.discarded_roll,
			DiceDisplay.ROLL_MODE_TEXTS[attack.roll_mode].to_lower(),
		]
	)


func _describe_damage(damage: DamageRoll) -> String:
	return _describe_dice(damage.dice_results, damage.damage_bonus)


func _describe_heal_title(combatant: Combatant, skill: SkillData) -> String:
	return "%s: %s" % [combatant.display_name, skill.display_name]


func _describe_heal(combatant: Combatant, heal: HealRoll, restored: int) -> String:
	var heal_text: String = (
		"%s heals %d (%s)"
		% [
			combatant.display_name,
			heal.total,
			_describe_dice(heal.dice_results, heal.heal_bonus),
		]
	)
	if restored < heal.total:
		return heal_text + ", capped at full health: +%d HP." % restored
	return heal_text + "."


func _describe_dice(dice_results: Array[int], bonus: int) -> String:
	return "dice %s, bonus %+d" % [DiceDisplay.join_dice_results(dice_results), bonus]


func _log(line: String) -> void:
	_combat_log.add_text(line + "\n")


func _on_round_started(round_number: int) -> void:
	_pending_events.append(_play_round_start.bind(round_number))


# Playback starts after the whole turn, so the hit points right after this attack are kept now.
func _on_attack_resolved(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
) -> void:
	_pending_events.append(
		_play_attack.bind(attacker, defender, attack, damage, defender.hit_points)
	)


func _on_momentum_changed(
	combatant: Combatant, momentum: int, change: int, reason: Combat.MomentumReason
) -> void:
	# A boss phase can change the cap later in the same turn, so it is kept now.
	var cap: int = RunState.GAME_RULES.momentum_cap
	var enemy: Enemy = combatant as Enemy
	if enemy != null:
		cap = enemy.momentum_cap()
	_pending_events.append(_play_momentum_change.bind(combatant, momentum, cap, change, reason))


# Intents can change before playback reaches this point, so they are copied now.
func _on_intents_announced() -> void:
	var intents: Dictionary[Enemy, EnemyIntentData] = {}
	for enemy: Combatant in _combat.living_enemies():
		intents[enemy as Enemy] = (enemy as Enemy).intent
	_pending_events.append(_play_intents.bind(intents))


func _on_player_blocked(player: Character) -> void:
	_pending_events.append(
		_log.bind(
			(
				"%s blocks: enemy attacks roll with disadvantage until your next turn."
				% player.display_name
			)
		)
	)


func _on_intent_started(enemy: Enemy, intent: EnemyIntentData) -> void:
	_pending_events.append(_play_intent_start.bind(enemy, intent))


# The phase changes the boss's values right away, so the ones shown at playback are kept now.
func _on_phase_started(boss: Enemy, phase: BossPhaseData) -> void:
	_pending_events.append(
		_play_phase_start.bind(
			boss, phase, boss.get_armor_class(), boss.momentum, boss.momentum_cap()
		)
	)


func _on_enemy_summoned(summon: Enemy) -> void:
	_pending_events.append(_play_summon.bind(summon))


func _on_player_turn_ended() -> void:
	_pending_events.append(_play_turn_end.bind(_is_ending_turn_by_hand))


func _on_skill_used(user: Combatant, skill: SkillData) -> void:
	_pending_events.append(_log.bind("%s uses %s." % [user.display_name, skill.display_name]))


func _on_combatant_healed(
	combatant: Combatant, heal: HealRoll, restored: int, skill: SkillData
) -> void:
	_pending_events.append(_play_heal.bind(combatant, skill, heal, restored, combatant.hit_points))


func _on_attacker_drained(attacker: Combatant, _drained: int, restored: int) -> void:
	_pending_events.append(_play_drain.bind(attacker, restored, attacker.hit_points))


func _on_combatant_defeated(combatant: Combatant) -> void:
	_pending_events.append(_play_defeat.bind(combatant))


func _on_combat_ended(player_won: bool) -> void:
	_pending_events.append(_play_combat_end.bind(player_won))


func _on_enemy_card_selected(card: CombatantCard) -> void:
	if not _can_act() or card.is_defeated():
		return
	_select_target(card)


func _on_attack_button_pressed() -> void:
	if not _can_attack():
		return
	_combat.player_attack(_target_card.combatant)
	_play_pending_events()


func _on_block_button_pressed() -> void:
	if not _can_act() or not _combat.can_block():
		return
	_combat.player_block()
	_play_pending_events()


func _on_end_turn_button_pressed() -> void:
	if not _can_act():
		return
	_is_ending_turn_by_hand = true
	_combat.end_turn()
	_is_ending_turn_by_hand = false
	_play_pending_events()


func _on_character_sheet_visibility_changed() -> void:
	if not is_node_ready() or _combat == null:
		return
	_refresh_actions()
	if not _character_sheet.visible:
		_focus_default_action()


func _on_skill_button_pressed(skill: SkillData) -> void:
	if not _can_act() or not _combat.can_use_skill(skill):
		return
	_combat.use_skill(skill)
	_play_pending_events()


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_continue_button_pressed() -> void:
	# Disabled first, so a second press cannot change the scene twice.
	_continue_button.disabled = true
	get_tree().change_scene_to_file(next_scene_path())
