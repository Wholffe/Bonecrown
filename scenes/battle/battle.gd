class_name Battle
extends Control
## Battle screen with combatant cards, dice display, combat log and action bar.

## Emitted after all queued combat events have been shown.
signal playback_finished

const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
# Placeholder encounter until the room sequence exists (milestone 7).
const ENCOUNTER: Array[EnemyData] = [GOBLIN, GOBLIN]
const COMBATANT_CARD_SCENE: PackedScene = preload("res://scenes/ui/combatant_card.tscn")
const ITEM_SLOT_SCENE: PackedScene = preload("res://scenes/ui/item_slot.tscn")
const EQUIPMENT_ICON_SIZE: float = 36.0
# A preload would form a cycle, because the main menu preloads this scene.
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"
# The post-fight screen leads back here, so a preload would form a cycle too.
const LEVEL_UP_SCENE_PATH: String = "res://scenes/levelup/level_up.tscn"
## The layout steps through these offsets when a crit is revealed, then returns to its rest.
const SHAKE_OFFSETS: Array[Vector2] = [
	Vector2(10, -6), Vector2(-9, 5), Vector2(7, 4), Vector2(-5, -3), Vector2(2, 2)
]
const SHAKE_STEP_DURATION: float = 0.035

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
@onready var _skill_buttons_box: VBoxContainer = %SkillButtons
@onready var _character_button: Button = %CharacterButton
@onready var _continue_button: Button = %ContinueButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _character_sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	_dice_display.animations_enabled = _animations_enabled
	_attack_button.pressed.connect(_on_attack_button_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	_continue_button.pressed.connect(_on_continue_button_pressed)
	_character_sheet.character = RunState.player
	_character_button.pressed.connect(_character_sheet.toggle)
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


## Tests and a later fast mode turn the roll animation off. Works before and after _ready().
func set_animations_enabled(enabled: bool) -> void:
	_animations_enabled = enabled
	if is_node_ready():
		_dice_display.animations_enabled = enabled


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
	var enemies: Array[Combatant] = Enemy.create_group(ENCOUNTER)
	_combat = Combat.new(RunState.player, enemies, RunState.dice)
	_combat.round_started.connect(_on_round_started)
	_combat.attack_resolved.connect(_on_attack_resolved)
	_combat.skill_used.connect(_on_skill_used)
	_combat.combatant_healed.connect(_on_combatant_healed)
	_combat.attacker_drained.connect(_on_attacker_drained)
	_combat.combatant_defeated.connect(_on_combatant_defeated)
	_combat.combat_ended.connect(_on_combat_ended)
	_create_cards(enemies)
	_create_skill_buttons()
	_log("Room %d   ·   Run seed: %d" % [RunState.room_number, RunState.run_seed])
	for enemy: Combatant in enemies:
		_log("A %s appears." % enemy.display_name)
	_select_target(_first_living_card())
	_combat.start()
	_play_pending_events()


func _create_cards(enemies: Array[Combatant]) -> void:
	var player: Combatant = _combat.player
	_player_card.show_combatant(player, true)
	_cards[player] = _player_card
	for enemy: Combatant in enemies:
		var card: CombatantCard = COMBATANT_CARD_SCENE.instantiate() as CombatantCard
		_enemy_cards_box.add_child(card)
		card.show_combatant(enemy, false)
		card.show_enemy_knowledge(RunState.enemy_knowledge)
		card.selected.connect(_on_enemy_card_selected)
		_cards[enemy] = card
		_enemy_cards.append(card)


func _create_skill_buttons() -> void:
	for skill: SkillData in _combat.player.active_skills():
		var button: Button = Button.new()
		button.name = skill.id.to_pascal_case() + "Button"
		button.tooltip_text = skill.description
		button.pressed.connect(_on_skill_button_pressed.bind(skill))
		_skill_buttons_box.add_child(button)
		_skill_buttons[skill] = button


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
	_refresh_actions()
	while not _pending_events.is_empty():
		var event: Callable = _pending_events.pop_front()
		await event.call()
	_is_playing_back = false
	_refresh_actions()
	_refresh_player_info()
	_refresh_roll_modes()
	if _continue_button.visible:
		_continue_button.grab_focus()
	elif _combat.is_over:
		_main_menu_button.grab_focus()
	else:
		_attack_button.grab_focus()
	playback_finished.emit()


func _play_round_start(round_number: int) -> void:
	_log("")
	_log("Round %d" % round_number)


func _play_attack(
	attacker: Combatant,
	defender: Combatant,
	attack: AttackRoll,
	damage: DamageRoll,
	defender_hit_points: int
) -> void:
	# Taken before the reveal, so the roll is shown against what the player knew when it was made.
	var armor_class_text: String = _describe_known_armor_class(defender, attack)
	await _dice_display.play_attack(attacker, defender, attack, damage, armor_class_text)
	_log(_describe_attack(attacker, defender, attack, damage, armor_class_text))
	if attack.is_natural_one:
		_log("Natural 1 – Off-Balance: next attack with disadvantage")
	_learn_from_attack(attacker, defender, attack)
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


# Learned on reveal, not when Combat resolves the attack, so no card shows more than the rolls
# the player has seen.
func _learn_from_attack(attacker: Combatant, defender: Combatant, attack: AttackRoll) -> void:
	var knowledge: EnemyKnowledge = RunState.enemy_knowledge
	var enemy: Enemy = defender as Enemy
	if enemy != null:
		knowledge.record_player_attack(enemy.data.id, attack)
	else:
		enemy = attacker as Enemy
		knowledge.record_enemy_attack(enemy.data.id, attack)
	for card: CombatantCard in _enemy_cards:
		if (card.combatant as Enemy).data.id == enemy.data.id:
			card.show_enemy_knowledge(knowledge)


func _play_defeat(combatant: Combatant) -> void:
	_log("%s is defeated." % combatant.display_name)
	if _cards[combatant] == _target_card:
		_select_target(_next_living_card(_target_card))


func _play_combat_end(player_won: bool) -> void:
	_log("")
	_log("Victory!" if player_won else "You have fallen. The run is over.")
	# Until the run end screen of milestone 11, a defeat only offers the main menu.
	_continue_button.visible = player_won


# The input handlers check this too, because a scripted pressed.emit() ignores disabled buttons.
func _can_act() -> bool:
	return not _is_playing_back and not _combat.is_over


func _can_attack() -> bool:
	return _can_act() and _target_card != null and _target_card.combatant.is_alive()


func _refresh_actions() -> void:
	var can_act: bool = _can_act()
	_attack_button.disabled = not _can_attack()
	for skill: SkillData in _skill_buttons:
		var button: Button = _skill_buttons[skill]
		button.text = _describe_skill_button(skill)
		button.disabled = not can_act or not _combat.can_use_skill(skill)
	_main_menu_button.disabled = _is_playing_back
	_continue_button.disabled = _is_playing_back
	for card: CombatantCard in _enemy_cards:
		card.set_selectable(can_act)


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


func _describe_skill_button(skill: SkillData) -> String:
	var uses: int = _combat.uses_left(skill)
	if uses == Combat.UNLIMITED_USES:
		return skill.display_name
	return "%s (%d)" % [skill.display_name, uses]


# The player always knows their own armor class, an enemy's only as far as the rolls proved it.
func _describe_known_armor_class(defender: Combatant, attack: AttackRoll) -> String:
	var enemy: Enemy = defender as Enemy
	if enemy == null:
		return CombatantCard.describe_armor_class(
			attack.target_armor_class, attack.target_armor_class
		)
	var knowledge: EnemyKnowledge = RunState.enemy_knowledge
	return CombatantCard.describe_armor_class(
		knowledge.lowest_armor_class(enemy.data.id), knowledge.highest_armor_class(enemy.data.id)
	)


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


func _on_skill_button_pressed(skill: SkillData) -> void:
	if not _can_act() or not _combat.can_use_skill(skill):
		return
	_combat.use_skill(skill)
	_play_pending_events()


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_continue_button_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_UP_SCENE_PATH)
