extends GutTest

const BONUS_CASES: Array = [
	[1, -5],
	[7, -2],
	[8, -1],
	[9, -1],
	[10, 0],
	[11, 0],
	[12, 1],
	[14, 2],
	[16, 3],
	[20, 5],
]


func test_bonus_for(params: Array = use_parameters(BONUS_CASES)) -> void:
	assert_eq(Attributes.bonus_for(params[0]), params[1], "value %d" % params[0])


func test_value_of_returns_constructor_values() -> void:
	var attributes: Attributes = Attributes.new(16, 12, 14, 10)

	assert_eq(attributes.value_of(Attributes.Kind.STRENGTH), 16)
	assert_eq(attributes.value_of(Attributes.Kind.DEXTERITY), 12)
	assert_eq(attributes.value_of(Attributes.Kind.CONSTITUTION), 14)
	assert_eq(attributes.value_of(Attributes.Kind.LUCK), 10)


func test_bonus_of_applies_formula_to_stored_value() -> void:
	var attributes: Attributes = Attributes.new(16, 12, 14, 9)

	assert_eq(attributes.bonus_of(Attributes.Kind.STRENGTH), 3)
	assert_eq(attributes.bonus_of(Attributes.Kind.DEXTERITY), 1)
	assert_eq(attributes.bonus_of(Attributes.Kind.CONSTITUTION), 2)
	assert_eq(attributes.bonus_of(Attributes.Kind.LUCK), -1)
