extends GutTest
## Battle scene in the boss room: phase changes, summoned enemies and the way to the run end.

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const BONE_KING: BossData = preload("res://scripts/data/enemies/bone_king.tres")
const SEED: int = 42
const BOSS_ROOM: int = 10


## Warrior: attack +5, d8+4, 14 HP. The Bone King: AC 16, attack +10, 1d10+6, phase 2 at 60 HP
## (Command and two Skeletons with attack +4), phase 3 at 30 HP (AC 14, Frenzy).
func _start_boss_battle(rolls: Array[int], boss_hit_points: int) -> Battle:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = BOSS_ROOM
	RunState.dice = FixedDice.new(rolls)
	var battle: Battle = BATTLE_SCENE.instantiate() as Battle
	battle.set_animations_enabled(false)
	add_child_autofree(battle)
	_boss(battle).hit_points = boss_hit_points
	return battle


func _enemy_cards(battle: Battle) -> Array[CombatantCard]:
	var cards: Array[CombatantCard] = []
	for child: Node in battle.get_node("%EnemyCards").get_children():
		cards.append(child as CombatantCard)
	return cards


func _boss(battle: Battle) -> Enemy:
	return _enemy_cards(battle)[0].combatant as Enemy


func _attack(battle: Battle) -> void:
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	await battle.wait_for_playback()


func _log_text(battle: Battle) -> String:
	return (battle.get_node("%CombatLog") as RichTextLabel).get_parsed_text()


func test_boss_room_holds_the_bone_king() -> void:
	var battle: Battle = _start_boss_battle([], BONE_KING.max_hit_points)

	assert_eq(_enemy_cards(battle).size(), 1)
	assert_eq(_boss(battle).data, BONE_KING)


func test_phase_change_is_announced_and_summons_get_cards() -> void:
	# Hit for 1 + 4 = 5 takes 61 HP to 56. Command rolls nothing, both Skeletons miss.
	var battle: Battle = _start_boss_battle([15, 1, 2, 2], 61)

	await _attack(battle)

	var cards: Array[CombatantCard] = _enemy_cards(battle)
	assert_eq(cards.size(), 3)
	assert_eq(cards[1].combatant.display_name, "Skeleton 1")
	assert_true(cards[1].is_selectable(), "Summons can be attacked")
	var log_text: String = _log_text(battle)
	assert_string_contains(log_text, BONE_KING.phases[0].announcement)
	assert_string_contains(log_text, "A Skeleton 2 appears.")


func test_phase_with_a_new_armor_class_updates_the_card() -> void:
	# 31 HP to 26 reaches both phases. Frenzy misses twice, both Skeletons miss.
	var battle: Battle = _start_boss_battle([15, 1, 2, 2, 2, 2], 31)

	await _attack(battle)

	var stats: Label = _enemy_cards(battle)[0].get_node("%StatsLabel") as Label
	assert_eq(stats.text, "AC 14   Attack +10")


func test_intent_without_attacks_names_only_its_effect() -> void:
	var battle: Battle = _start_boss_battle([], BONE_KING.max_hit_points)
	var command: EnemyIntentData = BONE_KING.phases[0].intents[0]

	var text: String = CombatantCard.describe_intent(_boss(battle), command)

	assert_eq(text, "Command: allies +1 Momentum")


func test_summons_fall_with_the_boss() -> void:
	# Round 1 calls the Skeletons, which miss. Round 2: 8 + 4 = 12 fells the boss at 5 HP.
	var battle: Battle = _start_boss_battle([15, 1, 2, 2, 15, 8], 61)
	await _attack(battle)
	_boss(battle).hit_points = 5

	await _attack(battle)

	for card: CombatantCard in _enemy_cards(battle):
		assert_true(card.is_defeated(), "%s still stands" % card.combatant.display_name)
	assert_true((battle.get_node("%ContinueButton") as Button).visible)


func test_boss_win_leads_to_the_run_end() -> void:
	var battle: Battle = _start_boss_battle([15, 1], 1)

	await _attack(battle)

	assert_true((battle.get_node("%ContinueButton") as Button).visible)
	assert_eq(battle.next_scene_path(), Battle.RUN_END_SCENE_PATH)


func test_death_leads_to_the_run_end() -> void:
	# The warrior misses and spends all Momentum, Royal Strike hits for 1 + 6.
	var battle: Battle = _start_boss_battle([2, 15, 1], BONE_KING.max_hit_points)
	RunState.player.hit_points = 1

	await _attack(battle)

	assert_false(RunState.player.is_alive())
	assert_true((battle.get_node("%ContinueButton") as Button).visible)
	assert_eq(battle.next_scene_path(), Battle.RUN_END_SCENE_PATH)


# The scene change itself would replace the running GUT scene, so only its target is checked.
func test_run_end_path_points_to_an_existing_scene() -> void:
	assert_true(ResourceLoader.exists(Battle.RUN_END_SCENE_PATH, "PackedScene"))
