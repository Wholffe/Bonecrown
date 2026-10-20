class_name SkillOfferRoller
extends RefCounted
## Draws the skills offered after a won fight from the skill pool of the player's class.

const OFFER_SIZE: int = 3

var _dice: DiceRoller


func _init(dice: DiceRoller) -> void:
	_dice = dice


## Up to OFFER_SIZE different random skills that are offerable at this level, fewer if the pool
## runs short. capped_attributes lists the attribute stats that are already at the attribute cap.
func roll_offer(
	pool: Array[SkillData],
	level: int,
	taken: Array[SkillData],
	capped_attributes: Array[StatModifierEffect.Stat]
) -> Array[SkillData]:
	var candidates: Array[SkillData] = []
	for skill: SkillData in pool:
		if (
			_is_offerable(skill, level, taken, capped_attributes)
			and not _contains_skill(candidates, skill)
		):
			candidates.append(skill)
	var offer: Array[SkillData] = []
	while offer.size() < OFFER_SIZE and not candidates.is_empty():
		var index: int = _dice.roll(candidates.size()) - 1
		offer.append(candidates[index])
		candidates.remove_at(index)
	return offer


func _is_offerable(
	skill: SkillData,
	level: int,
	taken: Array[SkillData],
	capped_attributes: Array[StatModifierEffect.Stat]
) -> bool:
	if skill.min_level > level:
		return false
	if not skill.stackable and _contains_skill(taken, skill):
		return false
	return not _raises_capped_attribute(skill, capped_attributes)


func _raises_capped_attribute(
	skill: SkillData, capped_attributes: Array[StatModifierEffect.Stat]
) -> bool:
	for effect: EffectData in skill.effects:
		var modifier: StatModifierEffect = effect as StatModifierEffect
		if modifier != null and modifier.amount > 0 and modifier.stat in capped_attributes:
			return true
	return false


# Compared by id, so a duplicated resource still counts as the same skill.
func _contains_skill(skills: Array[SkillData], skill: SkillData) -> bool:
	for other: SkillData in skills:
		if other.id == skill.id:
			return true
	return false
