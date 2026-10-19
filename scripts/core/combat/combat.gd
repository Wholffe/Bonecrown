class_name Combat
extends RefCounted
## Turn-based fight: the player acts first, then every living enemy. Reports each step via signals.

signal round_started(round_number: int)
signal attack_resolved(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
)
signal skill_used(user: Combatant, skill: SkillData)
signal combatant_healed(combatant: Combatant, heal: HealRoll, restored: int)
signal combatant_defeated(combatant: Combatant)
signal combat_ended(player_won: bool)

const UNLIMITED_USES: int = -1

var player: Character
var enemies: Array[Combatant] = []
var round_number: int = 0
var is_over: bool = false
var _dice: DiceRoller
var _resolver: AttackResolver
var _uses_left: Dictionary[SkillData, int] = {}


func _init(fight_player: Character, fight_enemies: Array[Combatant], dice: DiceRoller) -> void:
	assert(not fight_enemies.is_empty(), "A fight needs at least one enemy")
	player = fight_player
	enemies = fight_enemies
	_dice = dice
	_resolver = AttackResolver.new(dice)
	for skill: SkillData in fight_player.active_skills():
		if skill.uses_per_fight > 0:
			_uses_left[skill] = skill.uses_per_fight


## Separate from _init, so listeners can connect before the first round starts.
func start() -> void:
	_begin_round()


func living_enemies() -> Array[Combatant]:
	var living: Array[Combatant] = []
	for enemy: Combatant in enemies:
		if enemy.is_alive():
			living.append(enemy)
	return living


## Remaining uses of an active skill in this fight, or UNLIMITED_USES.
func uses_left(skill: SkillData) -> int:
	return _uses_left.get(skill, UNLIMITED_USES)


func can_use_skill(skill: SkillData) -> bool:
	return not is_over and skill in player.active_skills() and uses_left(skill) != 0


func player_attack(target: Combatant) -> void:
	assert(not is_over, "The fight is already over")
	assert(target in living_enemies(), "Target must be a living enemy of this fight")
	_attack(player, target)
	_finish_player_turn()


func use_skill(skill: SkillData) -> void:
	assert(can_use_skill(skill), "%s cannot be used now" % skill.id)
	if skill in _uses_left:
		_uses_left[skill] -= 1
	skill_used.emit(player, skill)
	for effect: EffectData in skill.effects:
		_apply_effect(effect)
	if skill.action_cost == SkillData.ActionCost.ACTION:
		_finish_player_turn()


func _begin_round() -> void:
	round_number += 1
	round_started.emit(round_number)


func _finish_player_turn() -> void:
	if living_enemies().is_empty():
		_end(true)
		return
	for enemy: Combatant in living_enemies():
		_attack(enemy, player)
		if not player.is_alive():
			_end(false)
			return
	_begin_round()


## The damage passed to attack_resolved is null on a miss.
func _attack(attacker: Combatant, defender: Combatant) -> void:
	var attack: AttackRoll = _resolver.roll_attack(
		attacker.get_attack_bonus(), defender.get_armor_class(), attacker.get_crit_threshold()
	)
	var damage: DamageRoll = null
	if attack.is_hit:
		damage = _resolver.roll_damage(
			attacker.get_damage_die_count(),
			attacker.get_damage_die_sides(),
			attacker.get_damage_bonus(),
			attack.is_crit
		)
		defender.take_damage(damage.total)
	attack_resolved.emit(attacker, defender, attack, damage)
	if not defender.is_alive():
		combatant_defeated.emit(defender)


func _apply_effect(effect: EffectData) -> void:
	var heal_effect: HealEffect = effect as HealEffect
	if heal_effect != null:
		_heal_player(heal_effect)
	else:
		push_error("Effect %s has no rule for active skills" % effect.get_script().resource_path)


func _heal_player(effect: HealEffect) -> void:
	var bonus: int = player.level if effect.adds_level else 0
	var heal: HealRoll = HealRoll.new(_dice.roll_many(effect.die_count, effect.die_sides), bonus)
	var restored: int = player.heal(heal.total)
	combatant_healed.emit(player, heal, restored)


func _end(player_won: bool) -> void:
	is_over = true
	combat_ended.emit(player_won)
