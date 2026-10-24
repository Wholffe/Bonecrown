extends GutTest
## Combat stat modifiers of Character: damage reduction, negative modifiers and the Adrenaline
## condition at half hit points.

const WARRIOR: ClassData = preload("res://scripts/data/classes/warrior.tres")
const GAME_RULES: GameRulesData = preload("res://scripts/data/game_rules.tres")
const IRON_SKIN: SkillData = preload("res://scripts/data/skills/iron_skin.tres")
const RECKLESS_SWINGS: SkillData = preload("res://scripts/data/skills/reckless_swings.tres")
const GUARDED_STANCE: SkillData = preload("res://scripts/data/skills/guarded_stance.tres")
const ADRENALINE: SkillData = preload("res://scripts/data/skills/adrenaline.tres")
const BONE_PLATE: ArmorData = preload("res://scripts/data/items/bone_plate.tres")
## 21 + constitution bonus 2 gives an odd maximum of 23 hit points.
const ODD_BASE_HIT_POINTS: int = 21
## The Warrior's damage bonus without Adrenaline: strength bonus 3 + Weapon Master 1.
const BASE_DAMAGE_BONUS: int = 4
const ADRENALINE_DAMAGE_BONUS: int = 2

var _warrior: Character


func before_each() -> void:
	_warrior = Character.new(WARRIOR, GAME_RULES)


func _talisman_with_damage_reduction(amount: int) -> TalismanData:
	var modifier: StatModifierEffect = StatModifierEffect.new()
	modifier.stat = StatModifierEffect.Stat.DAMAGE_REDUCTION
	modifier.amount = amount
	var talisman: TalismanData = TalismanData.new()
	talisman.id = &"test_damage_reduction_talisman"
	talisman.effects = [modifier]
	return talisman


func _adrenaline_warrior_with_base_hit_points(base_hit_points: int) -> Character:
	var class_data: ClassData = WARRIOR.duplicate()
	class_data.base_hit_points = base_hit_points
	var warrior: Character = Character.new(class_data, GAME_RULES)
	warrior.learn_skill(ADRENALINE)
	return warrior


func test_no_damage_reduction_without_modifiers() -> void:
	assert_eq(_warrior.get_damage_reduction(), 0)


func test_iron_skin_gives_damage_reduction_1() -> void:
	_warrior.learn_skill(IRON_SKIN)

	assert_eq(_warrior.get_damage_reduction(), 1)


func test_damage_reduction_sums_skill_and_item_modifiers() -> void:
	_warrior.learn_skill(IRON_SKIN)

	_warrior.equip(_talisman_with_damage_reduction(2))

	assert_eq(_warrior.get_damage_reduction(), 3, "Iron Skin 1 + talisman 2")


func test_reckless_swings_trades_armor_class_for_damage() -> void:
	_warrior.learn_skill(RECKLESS_SWINGS)

	assert_eq(_warrior.get_armor_class(), 13, "14 - 1")
	assert_eq(_warrior.get_damage_bonus(), 6, "4 + 2")


func test_guarded_stance_trades_damage_for_armor_class() -> void:
	_warrior.learn_skill(GUARDED_STANCE)

	assert_eq(_warrior.get_armor_class(), 15, "14 + 1")
	assert_eq(_warrior.get_damage_bonus(), 3, "4 - 1")


func test_bone_plate_lowers_attack_and_damage_by_2() -> void:
	_warrior.equip(BONE_PLATE)

	assert_eq(_warrior.get_attack_bonus(), 3, "5 - 2")
	assert_eq(_warrior.get_damage_bonus(), 2, "4 - 2")
	assert_eq(_warrior.get_armor_class(), 20, "base 13 + dexterity bonus 1 + 6")


func test_positive_and_negative_modifiers_on_one_stat_add_up() -> void:
	_warrior.learn_skill(RECKLESS_SWINGS)
	_warrior.learn_skill(GUARDED_STANCE)

	assert_eq(_warrior.get_armor_class(), 14, "14 - 1 + 1")
	assert_eq(_warrior.get_damage_bonus(), 5, "4 + 2 - 1")


func test_adrenaline_does_not_apply_at_full_hit_points() -> void:
	_warrior.learn_skill(ADRENALINE)

	assert_eq(_warrior.get_damage_bonus(), BASE_DAMAGE_BONUS)


func test_adrenaline_applies_at_exactly_half_hit_points() -> void:
	_warrior.learn_skill(ADRENALINE)

	_warrior.take_damage(7)

	assert_eq(_warrior.hit_points, 7, "half of 14")
	assert_eq(_warrior.get_damage_bonus(), BASE_DAMAGE_BONUS + ADRENALINE_DAMAGE_BONUS)


func test_adrenaline_does_not_apply_one_above_half_hit_points() -> void:
	_warrior.learn_skill(ADRENALINE)

	_warrior.take_damage(6)

	assert_eq(_warrior.hit_points, 8, "one above half of 14")
	assert_eq(_warrior.get_damage_bonus(), BASE_DAMAGE_BONUS)


func test_adrenaline_applies_at_11_of_odd_maximum_23() -> void:
	var warrior: Character = _adrenaline_warrior_with_base_hit_points(ODD_BASE_HIT_POINTS)

	warrior.take_damage(12)

	assert_eq(warrior.max_hit_points, 23)
	assert_eq(warrior.get_damage_bonus(), BASE_DAMAGE_BONUS + ADRENALINE_DAMAGE_BONUS, "11 of 23")


func test_adrenaline_does_not_apply_at_12_of_odd_maximum_23() -> void:
	var warrior: Character = _adrenaline_warrior_with_base_hit_points(ODD_BASE_HIT_POINTS)

	warrior.take_damage(11)

	assert_eq(warrior.max_hit_points, 23)
	assert_eq(warrior.get_damage_bonus(), BASE_DAMAGE_BONUS, "12 of 23")


func test_adrenaline_stops_applying_after_healing_above_half() -> void:
	_warrior.learn_skill(ADRENALINE)
	_warrior.take_damage(7)

	_warrior.heal(1)

	assert_eq(_warrior.get_damage_bonus(), BASE_DAMAGE_BONUS, "8 of 14")


func test_adrenaline_condition_follows_the_raised_maximum_after_level_up() -> void:
	_warrior.learn_skill(ADRENALINE)
	_warrior.take_damage(7)

	_warrior.level_up()

	assert_eq(_warrior.get_damage_bonus(), BASE_DAMAGE_BONUS, "15 of 22 is above half")
