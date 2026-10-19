extends GutTest
## Battle scene: marking an enemy by click and moving the mark when the marked enemy falls.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const SEED: int = 42


## Warrior: attack +5 vs AC 12, d8+4, 14 HP. Goblins: attack +3 vs AC 14, d6+1, 8 HP each.
func _start_battle(rolls: Array[int]) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)
	return battle


func _enemy_card(battle: Battle, index: int) -> CombatantCard:
	return battle.get_node("%EnemyCards").get_child(index) as CombatantCard


# GUT's output panel lies on top of the test scene and would catch a click pushed through the
# viewport, so the click goes straight to the card's input handler.
func _click(card: CombatantCard) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card._gui_input(click)


func _attack(battle: Battle) -> void:
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	await battle.wait_for_playback()


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func test_first_enemy_is_marked_at_start() -> void:
	var battle: Battle = _start_battle([])

	assert_true(_enemy_card(battle, 0).is_selected(), "Goblin 1 is the first living enemy")
	assert_false(_enemy_card(battle, 1).is_selected(), "Only one enemy is marked")
	assert_no_new_orphans()


func test_enemy_cards_can_be_marked_at_start() -> void:
	var battle: Battle = _start_battle([])

	assert_true(_enemy_card(battle, 0).is_selectable())
	assert_true(_enemy_card(battle, 1).is_selectable())
	assert_no_new_orphans()


func test_clicking_an_enemy_card_moves_the_mark() -> void:
	var battle: Battle = _start_battle([])

	_click(_enemy_card(battle, 1))

	assert_true(_enemy_card(battle, 1).is_selected())
	assert_false(_enemy_card(battle, 0).is_selected(), "Only one enemy is marked")
	assert_no_new_orphans()


func test_attack_hits_the_marked_enemy() -> void:
	var battle: Battle = _start_battle([17, 3, 2, 2])
	var first: CombatantCard = _enemy_card(battle, 0)
	var second: CombatantCard = _enemy_card(battle, 1)
	_click(second)

	await _attack(battle)

	assert_eq(second.combatant.hit_points, 1, "17 + 5 hits AC 12 for 3 + 4 damage")
	assert_eq(first.combatant.hit_points, first.combatant.max_hit_points, "Goblin 1 is untouched")
	var attack_line: String = (
		"%s attacks %s" % [RunState.player.display_name, second.combatant.display_name]
	)
	assert_string_contains(_log_text(battle), attack_line)
	assert_no_new_orphans()


func test_defeated_target_passes_the_mark_to_the_next_enemy() -> void:
	var battle: Battle = _start_battle([17, 4, 2])

	await _attack(battle)

	assert_true(_enemy_card(battle, 0).is_defeated(), "Precondition: 4 + 4 damage fells Goblin 1")
	assert_true(_enemy_card(battle, 1).is_selected())
	assert_false(_enemy_card(battle, 0).is_selected())
	assert_no_new_orphans()


func test_defeated_last_target_wraps_the_mark_to_the_first_enemy() -> void:
	var battle: Battle = _start_battle([17, 4, 2])
	_click(_enemy_card(battle, 1))

	await _attack(battle)

	assert_true(_enemy_card(battle, 1).is_defeated(), "Precondition: 4 + 4 damage fells Goblin 2")
	assert_true(_enemy_card(battle, 0).is_selected())
	assert_false(_enemy_card(battle, 1).is_selected())
	assert_no_new_orphans()


func test_clicking_a_defeated_card_keeps_the_mark() -> void:
	var battle: Battle = _start_battle([17, 4, 2])
	await _attack(battle)

	_click(_enemy_card(battle, 0))

	assert_true(_enemy_card(battle, 1).is_selected())
	assert_false(_enemy_card(battle, 0).is_selected(), "A defeated enemy cannot be marked")
	assert_no_new_orphans()


# The card itself ignores clicks once defeated. This checks the battle's own guard behind it.
func test_selected_signal_of_a_defeated_card_is_ignored() -> void:
	var battle: Battle = _start_battle([17, 4, 2])
	await _attack(battle)
	var defeated: CombatantCard = _enemy_card(battle, 0)

	defeated.selected.emit(defeated)

	assert_true(_enemy_card(battle, 1).is_selected())
	assert_false(defeated.is_selected(), "A defeated enemy cannot be marked")
	assert_no_new_orphans()
