class_name MapEvents
extends RefCounted
## What happens at the map's nodes without a fight: skill checks and resting.

var _dice: DiceRoller
var _economy: EconomyData


func _init(dice: DiceRoller, economy: EconomyData) -> void:
	_dice = dice
	_economy = economy


## A failed check costs the check's hit points right away.
func roll_check(character: Character, check: SkillCheckData) -> SkillCheckRoll:
	var result: SkillCheckRoll = SkillCheckRoll.new(
		_dice.roll(SkillCheckRoll.DIE_SIDES),
		character.attribute_bonus(check.attribute),
		check.difficulty
	)
	if not result.is_success:
		character.take_damage(check.fail_damage)
	return result


## Heals the rest share of the max hit points, rounded down, and returns the hit points restored.
func rest(character: Character) -> int:
	return character.heal(floori(character.max_hit_points * _economy.rest_heal_percent / 100.0))
