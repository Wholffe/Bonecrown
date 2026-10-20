extends GutTest
## Combatant card: exact player stats, hidden enemy stats and the known armor class text.

const COMBATANT_CARD_SCENE: PackedScene = preload("res://scenes/ui/combatant_card.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const SEED: int = 42
const NORMAL_CRIT_THRESHOLD: int = 20
const UNKNOWN: int = EnemyKnowledge.UNKNOWN
## Lowest and highest armor class the rolls allow, and the text for them.
const ARMOR_CLASS_CASES: Array = [
	[UNKNOWN, UNKNOWN, "AC ?"],
	[13, UNKNOWN, "AC ≥ 13"],
	[UNKNOWN, 15, "AC ≤ 15"],
	[13, 15, "AC 13–15"],
	[14, 14, "AC 14"],
]


func _create_card() -> CombatantCard:
	var card: CombatantCard = COMBATANT_CARD_SCENE.instantiate() as CombatantCard
	add_child_autofree(card)
	return card


func _stats_text(card: CombatantCard) -> String:
	return (card.get_node("%StatsLabel") as Label).text


func test_armor_class_text(params: Array = use_parameters(ARMOR_CLASS_CASES)) -> void:
	assert_eq(
		CombatantCard.describe_armor_class(params[0], params[1]),
		params[2],
		"lowest %d, highest %d" % [params[0], params[1]]
	)


func test_player_card_shows_the_exact_stats() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var card: CombatantCard = _create_card()

	card.show_combatant(RunState.player, true)

	assert_eq(_stats_text(card), "AC 14   Attack +5", "Warrior: AC 14, attack +5")
	assert_no_new_orphans()


func test_enemy_card_hides_the_stats() -> void:
	var card: CombatantCard = _create_card()

	card.show_combatant(Enemy.new(GOBLIN), false)

	assert_eq(_stats_text(card), "AC ?   Attack ?")
	assert_no_new_orphans()


func test_enemy_card_shows_what_was_learned_about_its_type() -> void:
	var knowledge: EnemyKnowledge = EnemyKnowledge.new()
	# 8 + 5 = 13 hits AC 12 narrowly, so the armor class is 12 or 13.
	knowledge.record_player_attack(GOBLIN.id, AttackRoll.new(8, 5, 12, NORMAL_CRIT_THRESHOLD))
	knowledge.record_enemy_attack(GOBLIN.id, AttackRoll.new(9, 3, 14, NORMAL_CRIT_THRESHOLD))
	var card: CombatantCard = _create_card()
	card.show_combatant(Enemy.new(GOBLIN), false)

	card.show_enemy_knowledge(knowledge)

	assert_eq(_stats_text(card), "AC 12–13   Attack +3")
	assert_no_new_orphans()
