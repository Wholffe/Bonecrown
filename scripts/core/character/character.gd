class_name Character
extends Combatant
## The player character: class data plus run progress (level, equipment, skills, hit points).

const STARTING_LEVEL: int = 1
const ATTRIBUTE_STATS: Dictionary[Attributes.Kind, StatModifierEffect.Stat] = {
	Attributes.Kind.STRENGTH: StatModifierEffect.Stat.STRENGTH,
	Attributes.Kind.DEXTERITY: StatModifierEffect.Stat.DEXTERITY,
	Attributes.Kind.CONSTITUTION: StatModifierEffect.Stat.CONSTITUTION,
	Attributes.Kind.LUCK: StatModifierEffect.Stat.LUCK,
}

var class_data: ClassData
## Base values from the class data. Values with skills and items come from attribute_value().
var attributes: Attributes
var level: int = STARTING_LEVEL
var weapon: WeaponData
var armor: ArmorData
## Empty until the first talisman is equipped.
var talisman: TalismanData
var skills: Array[SkillData] = []
## Earned in fights and for finds left behind, spent at merchants.
var gold: int = 0
var _rules: GameRulesData


func _init(data: ClassData, rules: GameRulesData) -> void:
	class_data = data
	display_name = data.display_name
	attributes = Attributes.new(data.strength, data.dexterity, data.constitution, data.luck)
	weapon = data.starting_weapon
	armor = data.starting_armor
	# assign() copies, so learning skills later never changes the shared class data.
	skills.assign(data.starting_skills)
	_rules = rules
	max_hit_points = _calculate_max_hit_points()
	hit_points = max_hit_points


## Independent copy for previews: learning or equipping on it never changes this character.
func copy() -> Character:
	# new() instead of Character.new(): naming its own class_name here leaks the script at exit.
	var duplicate_character: Character = new(class_data, _rules)
	duplicate_character.level = level
	duplicate_character.skills.assign(skills)
	duplicate_character.weapon = weapon
	duplicate_character.armor = armor
	duplicate_character.talisman = talisman
	duplicate_character.max_hit_points = duplicate_character._calculate_max_hit_points()
	duplicate_character.hit_points = hit_points
	duplicate_character.gold = gold
	return duplicate_character


func get_armor_class() -> int:
	return (
		CombatFormulas.armor_class(armor.armor_base, attribute_bonus(Attributes.Kind.DEXTERITY))
		+ stat_modifier(StatModifierEffect.Stat.ARMOR_CLASS)
	)


func get_attack_bonus() -> int:
	return (
		CombatFormulas.melee_attack_bonus(
			attribute_bonus(Attributes.Kind.STRENGTH), _rules.proficiency_bonus
		)
		+ stat_modifier(StatModifierEffect.Stat.ATTACK)
	)


func get_crit_threshold() -> int:
	return CombatFormulas.crit_threshold(attribute_bonus(Attributes.Kind.LUCK))


func get_damage_die_count() -> int:
	return weapon.damage_die_count


func get_damage_die_sides() -> int:
	return weapon.damage_die_sides


# Every weapon is a melee weapon so far, so melee damage modifiers always apply.
func get_damage_bonus() -> int:
	return (
		attribute_bonus(Attributes.Kind.STRENGTH)
		+ stat_modifier(StatModifierEffect.Stat.MELEE_DAMAGE)
	)


## Damage taken off each hit the character receives.
func get_damage_reduction() -> int:
	return stat_modifier(StatModifierEffect.Stat.DAMAGE_REDUCTION)


## Base value plus the modifiers of passive skills and worn items, capped by the game rules.
func attribute_value(kind: Attributes.Kind) -> int:
	return mini(
		attributes.value_of(kind) + stat_modifier(ATTRIBUTE_STATS[kind]), _rules.attribute_cap
	)


func attribute_bonus(kind: Attributes.Kind) -> int:
	return Attributes.bonus_for(attribute_value(kind))


## True when skills and items cannot raise the attribute any further.
func is_attribute_capped(kind: Attributes.Kind) -> bool:
	return attribute_value(kind) >= _rules.attribute_cap


## Sum of the stat's modifiers from passive skills and worn items whose conditions hold.
func stat_modifier(stat: StatModifierEffect.Stat) -> int:
	var total: int = 0
	for effect: EffectData in _passive_effects():
		var modifier: StatModifierEffect = effect as StatModifierEffect
		if modifier != null and modifier.stat == stat and _modifier_applies(modifier):
			total += modifier.amount
	return total


## Bonus on the loot roll from Luck.
func loot_bonus() -> int:
	return attribute_bonus(Attributes.Kind.LUCK)


## Max HP gained with the next level-up at the current Constitution.
func hit_points_per_level_up() -> int:
	return class_data.hit_points_per_level + attribute_bonus(Attributes.Kind.CONSTITUTION)


func worn_items() -> Array[ItemData]:
	var worn: Array[ItemData] = []
	for item: ItemData in [weapon, armor, talisman]:
		if item != null:
			worn.append(item)
	return worn


## The item worn in the slot, or null for an empty slot.
func item_in_slot(slot: ItemData.Slot) -> ItemData:
	match slot:
		ItemData.Slot.WEAPON:
			return weapon
		ItemData.Slot.ARMOR:
			return armor
		ItemData.Slot.TALISMAN:
			return talisman
	push_error("There is no item slot %d" % slot)
	return null


func active_skills() -> Array[SkillData]:
	var active: Array[SkillData] = []
	for skill: SkillData in skills:
		if skill.activation == SkillData.Activation.ACTIVE:
			active.append(skill)
	return active


## Stackable skills may be learned again, every copy counts. A higher rank of a skill tree node
## passes the rank it replaces.
func learn_skill(skill: SkillData, replaced: SkillData = null) -> void:
	if replaced != null:
		assert(replaced in skills, "Only a learned skill can be replaced")
		skills.erase(replaced)
	skills.append(skill)
	_update_max_hit_points()


## Puts the item into its slot and returns the item it replaces, or null for an empty slot.
func equip(item: ItemData) -> ItemData:
	var replaced: ItemData = null
	match item.get_slot():
		ItemData.Slot.WEAPON:
			replaced = weapon
			weapon = item as WeaponData
		ItemData.Slot.ARMOR:
			replaced = armor
			armor = item as ArmorData
		ItemData.Slot.TALISMAN:
			replaced = talisman
			talisman = item as TalismanData
	_update_max_hit_points()
	return replaced


func level_up() -> void:
	level += 1
	_update_max_hit_points()


# 5e formula: a Constitution change counts for every level reached so far, not only for later ones.
func _calculate_max_hit_points() -> int:
	return (
		class_data.base_hit_points
		+ attribute_bonus(Attributes.Kind.CONSTITUTION)
		+ (level - STARTING_LEVEL) * hit_points_per_level_up()
	)


# A higher maximum raises current hit points by the gain, so missing hit points stay missing (no
# full heal on level-up). A lower maximum only clamps them.
func _update_max_hit_points() -> void:
	var gain: int = _calculate_max_hit_points() - max_hit_points
	max_hit_points += gain
	hit_points = mini(hit_points + maxi(gain, 0), max_hit_points)


# Worn items count like passive skills.
func _passive_effects() -> Array[EffectData]:
	var effects: Array[EffectData] = []
	for skill: SkillData in skills:
		if skill.activation == SkillData.Activation.PASSIVE:
			effects.append_array(skill.effects)
	for item: ItemData in worn_items():
		effects.append_array(item.effects)
	return effects


# Conditions read hit points, so a conditional Constitution modifier would change max HP and with
# it its own condition. The data test rules that out.
func _modifier_applies(modifier: StatModifierEffect) -> bool:
	var conditional: ConditionalModifierEffect = modifier as ConditionalModifierEffect
	if conditional == null:
		return true
	match conditional.condition:
		ConditionalModifierEffect.Condition.OWN_HP_AT_MOST_HALF:
			return hit_points * 2 <= max_hit_points
	return false
