class_name StatSheet
extends RefCounted
## Snapshot of the values the player sees on the character sheet, as display text in a fixed order.
## Comparing two snapshots gives the "before → after" lines of skill and loot cards.

const LEVEL: String = "Level"
const MAX_HIT_POINTS: String = "Max HP"
const HIT_POINTS_PER_LEVEL: String = "HP per level-up"
const ARMOR_CLASS: String = "AC"
const ATTACK: String = "Attack"
const DAMAGE: String = "Damage"
const CRIT_RANGE: String = "Crits on"
const DAMAGE_REDUCTION: String = "Damage reduction"
const LOOT_ROLL: String = "Loot roll"
const ATTRIBUTE_LABELS: Dictionary[Attributes.Kind, String] = {
	Attributes.Kind.STRENGTH: "Strength",
	Attributes.Kind.DEXTERITY: "Dexterity",
	Attributes.Kind.CONSTITUTION: "Constitution",
	Attributes.Kind.LUCK: "Luck",
}
## Labels of the combat stats that conditional modifiers can change.
const CONDITIONAL_STAT_LABELS: Dictionary[StatModifierEffect.Stat, String] = {
	StatModifierEffect.Stat.ATTACK: ATTACK,
	StatModifierEffect.Stat.MELEE_DAMAGE: DAMAGE,
	StatModifierEffect.Stat.ARMOR_CLASS: ARMOR_CLASS,
	StatModifierEffect.Stat.DAMAGE_REDUCTION: DAMAGE_REDUCTION,
}

## Row labels in display order.
var labels: Array[String] = []
var _values: Dictionary[String, String] = {}


func _init(character: Character) -> void:
	_add(LEVEL, str(character.level))
	_add(MAX_HIT_POINTS, str(character.max_hit_points))
	_add(HIT_POINTS_PER_LEVEL, "%+d" % character.hit_points_per_level_up())
	_add(ARMOR_CLASS, str(character.get_armor_class()))
	_add(ATTACK, "%+d" % character.get_attack_bonus())
	_add(
		DAMAGE,
		dice_text(
			character.get_damage_die_count(),
			character.get_damage_die_sides(),
			character.get_damage_bonus()
		)
	)
	_add(CRIT_RANGE, crit_range_text(character.get_crit_threshold()))
	_add(DAMAGE_REDUCTION, str(character.get_damage_reduction()))
	_add(LOOT_ROLL, "d%d%+d" % [LootRoll.DIE_SIDES, character.loot_bonus()])
	for kind: Attributes.Kind in ATTRIBUTE_LABELS:
		_add(
			ATTRIBUTE_LABELS[kind],
			"%d (%+d)" % [character.attribute_value(kind), character.attribute_bonus(kind)]
		)


static func dice_text(die_count: int, die_sides: int, bonus: int) -> String:
	return "%dd%d%+d" % [die_count, die_sides, bonus]


static func crit_range_text(crit_threshold: int) -> String:
	if crit_threshold >= AttackRoll.DIE_SIDES:
		return str(AttackRoll.DIE_SIDES)
	return "%d–%d" % [crit_threshold, AttackRoll.DIE_SIDES]


## The rows whose text differs between the two snapshots, in display order.
static func changes(before: StatSheet, after: StatSheet) -> Array[Change]:
	var changed: Array[Change] = []
	for label: String in before.labels:
		if before.value_of(label) != after.value_of(label):
			changed.append(Change.new(label, before.value_of(label), after.value_of(label)))
	return changed


## What learning the skill would change. Both sides are compared at full HP, so conditional
## modifiers do not show up here but in condition_notes().
static func preview_skill(character: Character, skill: SkillData) -> Array[Change]:
	var after: Character = character.copy()
	after.learn_skill(skill)
	return _compare_at_full_hit_points(character, after)


## What equipping the item would change, including the loss of the item it replaces.
static func preview_item(character: Character, item: ItemData) -> Array[Change]:
	var after: Character = character.copy()
	after.equip(item)
	return _compare_at_full_hit_points(character, after)


## One line per conditional modifier, such as "While at 11 HP or less (half of 22): Damage +2".
static func condition_notes(max_hit_points: int, effects: Array[EffectData]) -> Array[String]:
	var notes: Array[String] = []
	for effect: EffectData in effects:
		var conditional: ConditionalModifierEffect = effect as ConditionalModifierEffect
		if conditional == null:
			continue
		var change_text: String = (
			"%s %+d" % [CONDITIONAL_STAT_LABELS[conditional.stat], conditional.amount]
		)
		match conditional.condition:
			ConditionalModifierEffect.Condition.OWN_HP_AT_MOST_HALF:
				notes.append(
					(
						"While at %d HP or less (half of %d): %s"
						% [floori(max_hit_points / 2.0), max_hit_points, change_text]
					)
				)
	return notes


func value_of(label: String) -> String:
	return _values[label]


static func _compare_at_full_hit_points(before: Character, after: Character) -> Array[Change]:
	var full_before: Character = before.copy()
	full_before.hit_points = full_before.max_hit_points
	after.hit_points = after.max_hit_points
	# new() instead of StatSheet.new(): naming its own class_name here leaks the script at exit.
	return changes(new(full_before), new(after))


func _add(label: String, value: String) -> void:
	labels.append(label)
	_values[label] = value


## One row that differs between two snapshots.
class Change:
	extends RefCounted

	var label: String
	var before: String
	var after: String

	func _init(row_label: String, before_value: String, after_value: String) -> void:
		label = row_label
		before = before_value
		after = after_value
