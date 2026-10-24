extends GutTest

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const BONE_KING: EnemyData = preload("res://scripts/data/enemies/bone_king.tres")
const SEED: int = 42
const ROLL_COUNT: int = 20
const ELITE_LOOT_BONUS: int = 3


func _roll_sequence() -> Array[int]:
	var rolls: Array[int] = []
	for _i: int in ROLL_COUNT:
		rolls.append(RunState.dice.roll(AttackRoll.DIE_SIDES))
	return rolls


func _enter(row: int, type: MapNode.Type) -> MapNode:
	var node: MapNode = MapNode.new(row, 0, type)
	RunState.enter_node(node)
	return node


func test_new_run_starts_in_first_room_with_full_health() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	assert_eq(RunState.run_seed, SEED)
	assert_eq(RunState.room_number, 1)
	assert_eq(RunState.player.hit_points, RunState.player.max_hit_points)


func test_new_run_starts_a_fresh_skill_tree_of_the_class() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var old_progress: SkillTreeProgress = RunState.skill_tree
	RunState.player.level_up()
	old_progress.learn(old_progress.tree.trunk.nodes[0], RunState.player)

	RunState.start_new_run(WARRIOR, SEED)

	assert_ne(RunState.skill_tree, old_progress)
	assert_eq(RunState.skill_tree.tree, WARRIOR.skill_tree)
	assert_eq(RunState.skill_tree.rank_of(WARRIOR.skill_tree.trunk.nodes[0]), 0)


func test_same_seed_repeats_the_run_dice() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var first: Array[int] = _roll_sequence()
	RunState.start_new_run(WARRIOR, SEED)
	var second: Array[int] = _roll_sequence()

	assert_eq(first, second)


func test_room_rewards_are_for_the_room_just_won() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.room_number, RunState.FIRST_ROOM)
	assert_eq(rewards.player, RunState.player)


func test_elite_node_rewards_add_the_elite_loot_bonus() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	_enter(5, MapNode.Type.ELITE)

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.loot_roll_bonus(), RunState.player.loot_bonus() + ELITE_LOOT_BONUS)


func test_other_room_rewards_add_no_room_loot_bonus() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(rewards.loot_roll_bonus(), RunState.player.loot_bonus())


func test_first_room_has_one_goblin() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	var enemies: Array[Combatant] = RunState.create_room_enemies()

	assert_eq(enemies.size(), 1)
	assert_eq(enemies[0].display_name, "Goblin")


# Scene tests replace the dice after start_new_run, so the room enemies must use the new ones.
func test_room_enemies_roll_with_the_current_run_dice() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var dice: FixedDice = FixedDice.new([2])
	RunState.dice = dice
	RunState.room_number = 4

	var enemies: Array[Combatant] = RunState.create_room_enemies()

	assert_eq(enemies[0].display_name, "Orc", "Roll 2 picks the second encounter of rooms 4-6")
	assert_eq(dice.remaining_rolls(), 0)


func test_new_run_draws_a_map_and_starts_before_its_first_row() -> void:
	RunState.start_new_run(WARRIOR, SEED)

	assert_eq(RunState.map.row_count, RunState.GAME_RULES.room_count)
	assert_null(RunState.current_node)
	assert_true(RunState.walked.is_empty())
	assert_eq(RunState.available_nodes(), RunState.map.start_nodes())


func test_same_seed_draws_the_same_map() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var first: RunMap = RunState.map
	RunState.start_new_run(WARRIOR, SEED)

	assert_eq(RunState.map.nodes.size(), first.nodes.size())
	for index: int in first.nodes.size():
		assert_eq(RunState.map.nodes[index].type, first.nodes[index].type, "node %d" % index)
		assert_eq(RunState.map.nodes[index].lane, first.nodes[index].lane, "node %d" % index)


func test_entering_a_node_moves_to_its_room_and_offers_its_next_nodes() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var first: MapNode = RunState.available_nodes()[0]

	RunState.enter_node(first)

	assert_eq(RunState.current_node, first)
	assert_eq(RunState.room_number, first.row)
	assert_eq(RunState.walked, [first] as Array[MapNode])
	assert_eq(RunState.available_nodes(), first.next_nodes)


func test_boss_room_is_the_last_room() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	_enter(RunState.GAME_RULES.room_count - 1, MapNode.Type.REST)
	assert_false(RunState.is_boss_room())

	_enter(RunState.GAME_RULES.room_count, MapNode.Type.BOSS)

	assert_true(RunState.is_boss_room())


func test_boss_room_has_the_boss() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.room_number = RunState.GAME_RULES.room_count

	var enemies: Array[Combatant] = RunState.create_room_enemies()

	assert_eq(enemies.size(), 1)
	assert_eq((enemies[0] as Enemy).data, BONE_KING)


func test_fight_node_keeps_its_enemies() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var node: MapNode = GoblinPairNode.create()
	RunState.enter_node(node)

	assert_eq(RunState.create_room_enemies(), node.enemies)
	assert_eq(RunState.create_room_enemies(), node.enemies, "the same enemies again")


func test_elite_node_rolls_from_the_elite_pool() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.dice = FixedDice.new([2])
	_enter(5, MapNode.Type.ELITE)

	var enemies: Array[Combatant] = RunState.create_room_enemies()

	assert_eq(enemies[0].display_name, "Elite Orc")


func test_treasure_node_rewards_add_the_treasure_loot_bonus() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	_enter(3, MapNode.Type.TREASURE)

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(
		rewards.loot_roll_bonus(),
		RunState.player.loot_bonus() + RunState.ECONOMY.treasure_loot_bonus
	)


func test_sealed_treasure_adds_the_sealed_bonus() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var node: MapNode = _enter(3, MapNode.Type.TREASURE)
	node.check = RunState.MAP_TABLE.skill_checks[0]

	var rewards: RoomRewards = RunState.start_room_rewards()

	assert_eq(
		rewards.loot_roll_bonus(),
		(
			RunState.player.loot_bonus()
			+ RunState.ECONOMY.treasure_loot_bonus
			+ RunState.ECONOMY.sealed_treasure_loot_bonus
		)
	)


func test_new_run_clears_the_current_node_and_the_walked_path() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	RunState.enter_node(RunState.available_nodes()[0])

	RunState.start_new_run(WARRIOR, SEED)

	assert_null(RunState.current_node)
	assert_true(RunState.walked.is_empty())
	assert_eq(RunState.room_number, RunState.FIRST_ROOM)
