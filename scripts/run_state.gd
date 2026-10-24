extends Node
## Autoload that holds the current run: seed, dice, player character, skill tree, map and the node
## the player is in.

const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const LOOT_TABLE: LootTableData = preload("res://scripts/data/loot/loot_table.tres")
const ROOM_TABLE: RoomTableData = preload("res://scripts/data/rooms/room_table.tres")
const MAP_TABLE: MapTableData = preload("res://scripts/data/map/map_table.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
const FIRST_ROOM: int = 1

var run_seed: int
var dice: DiceRoller
var player: Character
## Null for a class without a skill tree.
var skill_tree: SkillTreeProgress
var map: RunMap
## The node the player is in or has just finished. Null before the first node.
var current_node: MapNode = null
## Every node entered so far, in order.
var walked: Array[MapNode] = []
## The row of the current node, which is also its room number.
var room_number: int = FIRST_ROOM


func start_new_run(class_data: ClassData, seed_value: int) -> void:
	run_seed = seed_value
	dice = DiceRoller.new(seed_value)
	player = Character.new(class_data, GAME_RULES)
	skill_tree = null
	if class_data.skill_tree != null:
		skill_tree = SkillTreeProgress.new(class_data.skill_tree)
	map = MapGenerator.new(dice, MAP_TABLE).generate(GAME_RULES.room_count)
	current_node = null
	walked = []
	room_number = FIRST_ROOM


## The nodes the player can enter next: the first row at the start, then the current node's next
## nodes.
func available_nodes() -> Array[MapNode]:
	if current_node == null:
		return map.start_nodes()
	return current_node.next_nodes


func enter_node(node: MapNode) -> void:
	current_node = node
	walked.append(node)
	room_number = node.row


func is_elite_node() -> bool:
	return current_node != null and current_node.type == MapNode.Type.ELITE


func is_treasure_node() -> bool:
	return current_node != null and current_node.type == MapNode.Type.TREASURE


## The enemies of the current fight node, created once and kept on the node. Without a node they
## are rolled for the room.
func create_room_enemies() -> Array[Combatant]:
	if current_node == null:
		return _encounter_roller().roll_enemies(room_number)
	if current_node.enemies.is_empty():
		current_node.enemies = _encounter_roller().roll_enemies(room_number, is_elite_node())
	return current_node.enemies


## The rewards of the current node: after a fight, or at a treasure with the treasure's loot bonus.
## The caller shows them and then returns to the map.
func start_room_rewards() -> RoomRewards:
	var loot_bonus: int = _encounter_roller().loot_bonus(is_elite_node())
	if is_treasure_node():
		loot_bonus = ECONOMY.treasure_loot_bonus
		if current_node.check != null:
			loot_bonus += ECONOMY.sealed_treasure_loot_bonus
	return RoomRewards.new(player, room_number, loot_bonus, dice, LOOT_TABLE, ECONOMY)


func create_map_events() -> MapEvents:
	return MapEvents.new(dice, ECONOMY)


func create_merchant_stock() -> MerchantStock:
	return MerchantStock.new(dice, LOOT_TABLE, ECONOMY, player, room_number)


## The last room of the run holds the boss.
func is_boss_room() -> bool:
	return room_number == GAME_RULES.room_count


## The only place that uses unseeded randomness: picking the seed of a new run.
func new_random_seed() -> int:
	var seed_source: RandomNumberGenerator = RandomNumberGenerator.new()
	seed_source.randomize()
	return seed_source.randi()


# Built on demand, so it always rolls with the current dice (tests replace them after a new run).
func _encounter_roller() -> EncounterRoller:
	return EncounterRoller.new(dice, ROOM_TABLE)
