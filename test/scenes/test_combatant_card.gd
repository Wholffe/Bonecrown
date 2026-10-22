extends GutTest
## Combatant card: exact stats of the player and of enemies, and the roll mode tag.

const COMBATANT_CARD_SCENE: PackedScene = preload("res://scenes/ui/combatant_card.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GOBLIN: EnemyData = preload("res://scripts/data/enemies/goblin.tres")
const SEED: int = 42
## Roll mode and the text of its tag.
const TAGGED_ROLL_MODE_CASES: Array = [
	[AttackRoll.RollMode.ADVANTAGE, "Advantage"],
	[AttackRoll.RollMode.DISADVANTAGE, "Disadvantage"],
]


func _create_card() -> CombatantCard:
	var card: CombatantCard = COMBATANT_CARD_SCENE.instantiate() as CombatantCard
	add_child_autofree(card)
	return card


func _stats_text(card: CombatantCard) -> String:
	return (card.get_node("%StatsLabel") as Label).text


func _roll_mode_label(card: CombatantCard) -> Label:
	return card.get_node("%RollModeLabel") as Label


func test_player_card_shows_the_exact_stats() -> void:
	RunState.start_new_run(WARRIOR, SEED)
	var card: CombatantCard = _create_card()

	card.show_combatant(RunState.player, true)

	assert_eq(_stats_text(card), "AC 14   Attack +5", "Warrior: AC 14, attack +5")
	assert_no_new_orphans()


func test_enemy_card_shows_the_exact_stats() -> void:
	var card: CombatantCard = _create_card()

	card.show_combatant(Enemy.new(GOBLIN), false)

	assert_eq(_stats_text(card), "AC 12   Attack +3")
	assert_no_new_orphans()


func test_card_starts_without_a_roll_mode_tag() -> void:
	var card: CombatantCard = _create_card()

	card.show_combatant(Enemy.new(GOBLIN), false)

	assert_false(_roll_mode_label(card).visible)
	assert_no_new_orphans()


func test_roll_mode_tag_names_the_roll_mode(
	params: Array = use_parameters(TAGGED_ROLL_MODE_CASES)
) -> void:
	var card: CombatantCard = _create_card()

	card.show_roll_mode(params[0])

	var tag: Label = _roll_mode_label(card)
	assert_true(tag.visible, "The tag is shown")
	assert_eq(tag.text, params[1])
	assert_eq(tag.get_theme_color("font_color"), DiceDisplay.ROLL_MODE_COLORS[params[0]])
	assert_no_new_orphans()


func test_normal_roll_mode_removes_the_tag() -> void:
	var card: CombatantCard = _create_card()
	card.show_roll_mode(AttackRoll.RollMode.DISADVANTAGE)

	card.show_roll_mode(AttackRoll.RollMode.NORMAL)

	assert_false(_roll_mode_label(card).visible)
	assert_no_new_orphans()
