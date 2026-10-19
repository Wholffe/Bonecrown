extends Control
## Battle screen with combatant cards, dice display, combat log and action bar.

## Emitted after all queued combat events have been shown.
signal playback_finished

const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
# Placeholder encounter until the room sequence exists (milestone 7).
const ENCOUNTER: Array[EnemyData] = [GOBLIN, GOBLIN]
const COMBATANT_CARD_SCENE: PackedScene = preload("res://scenes/ui/combatant_card.tscn")
# A preload would form a cycle, because the main menu preloads this scene.
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"

var _combat: Combat
var _cards: Dictionary[Combatant, CombatantCard] = {}
var _enemy_cards: Array[CombatantCard] = []
var _target_card: CombatantCard
var _skill_buttons: Dictionary[SkillData, Button] = {}
# Combat resolves a whole turn at once, so its signals queue events that are played back in order.
var _pending_events: Array[Callable] = []
var _is_playing_back: bool = false
var _used_skill: SkillData

@onready var _player_card: CombatantCard = %PlayerCard
@onready var _player_level_label: Label = %PlayerLevelLabel
@onready var _player_skills_label: Label = %PlayerSkillsLabel
@onready var _enemy_cards_box: HBoxContainer = %EnemyCards
@onready var _dice_display: DiceDisplay = %DiceDisplay
@onready var _combat_log: RichTextLabel = %CombatLog
@onready var _attack_button: Button = %AttackButton
@onready var _skill_buttons_box: VBoxContainer = %SkillButtons
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	_attack_button.pressed.connect(_on_attack_button_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	_start_combat()


func is_playing_back() -> bool:
	return _is_playing_back


## Tests and a later fast mode turn the roll animation off.
func set_animations_enabled(enabled: bool) -> void:
	_dice_display.animations_enabled = enabled


func _start_combat() -> void:
	var enemies: Array[Combatant] = Enemy.create_group(ENCOUNTER)
	_combat = Combat.new(RunState.player, enemies, RunState.dice)
	_combat.round_started.connect(_on_round_started)
	_combat.attack_resolved.connect(_on_attack_resolved)
	_combat.skill_used.connect(_on_skill_used)
	_combat.combatant_healed.connect(_on_combatant_healed)
	_combat.combatant_defeated.connect(_on_combatant_defeated)
	_combat.combat_ended.connect(_on_combat_ended)
	_create_cards(enemies)
	_create_skill_buttons()
	_log("Run seed: %d" % RunState.run_seed)
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
		_refresh_actions()
	_is_playing_back = false
	_refresh_actions()
	_refresh_player_info()
	if _combat.is_over:
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
	await _dice_display.play_attack(attacker, defender, attack, damage)
	_log(_describe_attack(attacker, defender, attack, damage))
	_cards[defender].show_hit_points(defender_hit_points)
	await _dice_display.hold()


func _play_heal(
	combatant: Combatant, skill: SkillData, heal: HealRoll, restored: int, hit_points: int
) -> void:
	await _dice_display.play_heal(combatant, skill, heal, restored)
	_log(_describe_heal(combatant, heal, restored))
	_cards[combatant].show_hit_points(hit_points)
	await _dice_display.hold()


func _play_defeat(combatant: Combatant) -> void:
	_log("%s is defeated." % combatant.display_name)
	if _cards[combatant] == _target_card:
		_select_target(_next_living_card(_target_card))


func _play_combat_end(player_won: bool) -> void:
	_log("")
	_log("Victory!" if player_won else "You have fallen. The run is over.")


func _refresh_actions() -> void:
	var can_act: bool = not _is_playing_back and not _combat.is_over
	_attack_button.disabled = not can_act or _target_card == null
	for skill: SkillData in _skill_buttons:
		var button: Button = _skill_buttons[skill]
		button.text = _describe_skill_button(skill)
		button.disabled = not can_act or not _combat.can_use_skill(skill)
	_main_menu_button.disabled = _is_playing_back
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


func _describe_skill_button(skill: SkillData) -> String:
	var uses: int = _combat.uses_left(skill)
	if uses == Combat.UNLIMITED_USES:
		return skill.display_name
	return "%s (%d)" % [skill.display_name, uses]


func _describe_attack(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
) -> String:
	var roll_text: String = (
		"%s attacks %s: d20 %d %+d = %d vs AC %d"
		% [
			attacker.display_name,
			defender.display_name,
			attack.natural_roll,
			attack.attack_bonus,
			attack.total,
			attack.target_armor_class,
		]
	)
	if attack.is_natural_one:
		return roll_text + " - natural 1, automatic miss."
	if not attack.is_hit:
		return roll_text + " - miss."
	var hit_text: String = "critical hit!" if attack.is_crit else "hit,"
	return roll_text + " - %s %d damage (%s)." % [hit_text, damage.total, _describe_damage(damage)]


func _describe_damage(damage: DamageRoll) -> String:
	return _describe_dice(damage.dice_results, damage.damage_bonus)


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
	var dice_texts: PackedStringArray = []
	for result: int in dice_results:
		dice_texts.append(str(result))
	return "dice %s, bonus %+d" % [" + ".join(dice_texts), bonus]


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
	_used_skill = skill
	_pending_events.append(_log.bind("%s uses %s." % [user.display_name, skill.display_name]))


# combatant_healed does not name its source, so the heal is shown with the skill just used.
func _on_combatant_healed(combatant: Combatant, heal: HealRoll, restored: int) -> void:
	_pending_events.append(
		_play_heal.bind(combatant, _used_skill, heal, restored, combatant.hit_points)
	)


func _on_combatant_defeated(combatant: Combatant) -> void:
	_pending_events.append(_play_defeat.bind(combatant))


func _on_combat_ended(player_won: bool) -> void:
	_pending_events.append(_play_combat_end.bind(player_won))


func _on_enemy_card_selected(card: CombatantCard) -> void:
	_select_target(card)


func _on_attack_button_pressed() -> void:
	_combat.player_attack(_target_card.combatant)
	_play_pending_events()


func _on_skill_button_pressed(skill: SkillData) -> void:
	_combat.use_skill(skill)
	_play_pending_events()


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
