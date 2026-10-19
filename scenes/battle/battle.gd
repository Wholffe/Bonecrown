extends Control
## Battle screen with a text log. Milestone 4 adds the dice display and the action bar.

# Placeholder encounter until the room sequence exists (milestone 7).
const ENCOUNTER: Array[EnemyData] = [preload("res://scripts/data/enemies/goblin.tres")]
# A preload would form a cycle, because the main menu preloads this scene.
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"

var _combat: Combat

@onready var _player_status: Label = %PlayerStatus
@onready var _enemy_status: Label = %EnemyStatus
@onready var _combat_log: RichTextLabel = %CombatLog
@onready var _attack_button: Button = %AttackButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	_attack_button.pressed.connect(_on_attack_button_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	_start_combat()
	_attack_button.grab_focus()


func _start_combat() -> void:
	var enemies: Array[Combatant] = []
	for enemy_data: EnemyData in ENCOUNTER:
		enemies.append(Enemy.new(enemy_data))
	_combat = Combat.new(RunState.player, enemies, RunState.dice)
	_combat.round_started.connect(_on_round_started)
	_combat.attack_resolved.connect(_on_attack_resolved)
	_combat.combatant_defeated.connect(_on_combatant_defeated)
	_combat.combat_ended.connect(_on_combat_ended)
	_log("Run seed: %d" % RunState.run_seed)
	for enemy: Combatant in enemies:
		_log("A %s appears." % enemy.display_name)
	_combat.start()
	_refresh_status()


func _refresh_status() -> void:
	var player: Character = RunState.player
	_player_status.text = (
		"%s  (Level %d)\n%s" % [player.display_name, player.level, _describe_stats(player)]
	)
	var lines: PackedStringArray = []
	for enemy: Combatant in _combat.enemies:
		lines.append("%s\n%s" % [enemy.display_name, _describe_stats(enemy)])
	_enemy_status.text = "\n".join(lines)


func _describe_stats(combatant: Combatant) -> String:
	return (
		"HP %d/%d   AC %d   Attack %+d"
		% [
			combatant.hit_points,
			combatant.max_hit_points,
			combatant.get_armor_class(),
			combatant.get_attack_bonus(),
		]
	)


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
	var dice_texts: PackedStringArray = []
	for result: int in damage.dice_results:
		dice_texts.append(str(result))
	return "dice %s, bonus %+d" % [" + ".join(dice_texts), damage.damage_bonus]


func _log(line: String) -> void:
	_combat_log.add_text(line + "\n")


func _on_round_started(round_number: int) -> void:
	_log("")
	_log("Round %d" % round_number)


func _on_attack_resolved(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
) -> void:
	_log(_describe_attack(attacker, defender, attack, damage))


func _on_combatant_defeated(combatant: Combatant) -> void:
	_log("%s is defeated." % combatant.display_name)


func _on_combat_ended(player_won: bool) -> void:
	_log("")
	_log("Victory!" if player_won else "You have fallen. The run is over.")
	_attack_button.disabled = true
	_main_menu_button.grab_focus()


func _on_attack_button_pressed() -> void:
	# Target selection arrives with groups in milestone 4, until then the first living enemy.
	_combat.player_attack(_combat.living_enemies()[0])
	_refresh_status()


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
