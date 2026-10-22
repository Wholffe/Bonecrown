extends GutTest
## Content rules of the game rules that apply to every class.

const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
## A run has 10 rooms, and the boss waits in the last one (brief).
const ROOM_COUNT: int = 10


func test_attribute_cap_is_positive() -> void:
	assert_gt(GAME_RULES.attribute_cap, 0)


func test_run_has_ten_rooms() -> void:
	assert_eq(GAME_RULES.room_count, ROOM_COUNT)
