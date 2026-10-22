extends GutTest
## Post-fight screen: the reward of the door chosen before the fight.

const LEVEL_UP_SCENE: PackedScene = preload("res://scenes/levelup/level_up.tscn")
const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const TREASURE: DoorRewardData = preload("res://scripts/data/doors/treasure.tres")
const HEALING_SPRING: DoorRewardData = preload("res://scripts/data/doors/healing_spring.tres")
const SEED: int = 7


func before_each() -> void:
	RunState.start_new_run(WARRIOR, SEED)


## Opens the screen for room 1 after a fight behind a door with reward, at 4 of 14 HP.
func _create(reward: DoorRewardData) -> LevelUp:
	RunState.player.take_damage(10)
	var door: DoorOption = GoblinPairDoor.create()
	door.reward = reward
	RunState.choose_door(door)
	RunState.dice = FixedDice.new([])
	var level_up: LevelUp = LEVEL_UP_SCENE.instantiate() as LevelUp
	level_up.set_animations_enabled(false)
	add_child_autofree(level_up)
	return level_up


func _door_reward_label(level_up: LevelUp) -> Label:
	return level_up.get_node("%DoorRewardLabel") as Label


func test_healing_spring_heals_before_the_level_up() -> void:
	var level_up: LevelUp = _create(HEALING_SPRING)

	var label: Label = _door_reward_label(level_up)
	assert_true(label.visible)
	assert_eq(label.text, "Healing Spring: +1 HP", "10% of 14 HP, rounded down")
	assert_eq((level_up.get_node("%HitPointsLabel") as Label).text, "HP 13 / 22", "4 + 1 + 8")
	assert_eq((level_up.get_node("%LevelUpLabel") as Label).text, "Level 2!   Max HP 14 → 22 (+8)")


func test_treasure_shows_in_the_loot_roll_bonus_without_a_heal_line() -> void:
	var level_up: LevelUp = _create(TREASURE)

	assert_false(_door_reward_label(level_up).visible)
	assert_string_starts_with(
		(level_up.get_node("%LootInfoLabel") as Label).text, "Loot roll d20+3"
	)
	assert_eq(RunState.player.hit_points, 12, "4 HP and the level-up's 8")


func test_door_without_a_reward_shows_no_heal_line() -> void:
	var level_up: LevelUp = _create(null)

	assert_false(_door_reward_label(level_up).visible)
