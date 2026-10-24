extends GutTest
## MapEvents: skill checks with d20 + attribute bonus against the difficulty, and resting.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const ECONOMY: EconomyData = preload("res://scripts/data/map/economy.tres")
## Strength 16 gives +3.
const STRENGTH_BONUS: int = 3
const DIFFICULTY: int = 14
const FAIL_DAMAGE: int = 4

var _player: Character
var _check: SkillCheckData


func before_each() -> void:
	_player = Character.new(WARRIOR, GAME_RULES)
	_check = SkillCheckData.new()
	_check.attribute = Attributes.Kind.STRENGTH
	_check.difficulty = DIFFICULTY
	_check.fail_damage = FAIL_DAMAGE


func _events(rolls: Array[int]) -> MapEvents:
	return MapEvents.new(FixedDice.new(rolls), ECONOMY)


func test_check_adds_the_attribute_bonus_and_succeeds_on_the_difficulty() -> void:
	var result: SkillCheckRoll = _events([DIFFICULTY - STRENGTH_BONUS]).roll_check(_player, _check)

	assert_eq(result.attribute_bonus, STRENGTH_BONUS)
	assert_eq(result.total, DIFFICULTY)
	assert_true(result.is_success, "the total reaches the difficulty")
	assert_eq(_player.hit_points, _player.max_hit_points, "a success costs nothing")


func test_failed_check_costs_its_hit_points() -> void:
	var result: SkillCheckRoll = _events([DIFFICULTY - STRENGTH_BONUS - 1]).roll_check(
		_player, _check
	)

	assert_false(result.is_success)
	assert_eq(_player.hit_points, _player.max_hit_points - FAIL_DAMAGE)


func test_rest_heals_its_share_of_max_hit_points_rounded_down() -> void:
	_player.take_damage(10)

	var healed: int = _events([]).rest(_player)

	assert_eq(healed, floori(_player.max_hit_points * ECONOMY.rest_heal_percent / 100.0))


func test_rest_never_heals_above_max_hit_points() -> void:
	_player.take_damage(1)

	assert_eq(_events([]).rest(_player), 1)
	assert_eq(_player.hit_points, _player.max_hit_points)
