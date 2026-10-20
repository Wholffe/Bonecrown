class_name Combat
extends RefCounted
## Turn-based fight: the player acts first, then every living enemy. Reports each step via signals.

signal round_started(round_number: int)
signal attack_resolved(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
)
signal skill_used(user: Combatant, skill: SkillData)
signal combatant_healed(combatant: Combatant, heal: HealRoll, restored: int)
## A natural 20 heals the attacker for half the damage rolled. Emitted right after attack_resolved.
signal attacker_drained(attacker: Combatant, drained: int, restored: int)
signal combatant_defeated(combatant: Combatant)
signal combat_ended(player_won: bool)

const UNLIMITED_USES: int = -1
## Drain heals the damage rolled divided by this, rounded down.
const DRAIN_DIVISOR: int = 2

var player: Character
var enemies: Array[Combatant] = []
var round_number: int = 0
var is_over: bool = false
var _dice: DiceRoller
var _resolver: AttackResolver
var _uses_spent: Dictionary[SkillData, int] = {}
## Set by an advantage effect such as Focus, spent on the player's next attack this turn.
var _player_has_advantage: bool = false
## Combatants whose last attack roll was a natural 1: their next one has disadvantage.
var _off_balance: Array[Combatant] = []


func _init(fight_player: Character, fight_enemies: Array[Combatant], dice: DiceRoller) -> void:
	assert(not fight_enemies.is_empty(), "A fight needs at least one enemy")
	player = fight_player
	enemies = fight_enemies
	_dice = dice
	_resolver = AttackResolver.new(dice)


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
	if skill.uses_per_fight == 0:
		return UNLIMITED_USES
	return maxi(skill.uses_per_fight - _uses_spent.get(skill, 0), 0)


## Roll mode of the combatant's next attack roll, for previews in the UI.
func next_roll_mode(combatant: Combatant) -> AttackRoll.RollMode:
	var has_advantage: bool = combatant == player and _player_has_advantage
	var has_disadvantage: bool = combatant in _off_balance
	# Advantage and disadvantage cancel each other out (5e).
	if has_advantage == has_disadvantage:
		return AttackRoll.RollMode.NORMAL
	if has_advantage:
		return AttackRoll.RollMode.ADVANTAGE
	return AttackRoll.RollMode.DISADVANTAGE


func can_use_skill(skill: SkillData) -> bool:
	return not is_over and skill in player.active_skills() and uses_left(skill) != 0


func player_attack(target: Combatant) -> void:
	assert(not is_over, "The fight is already over")
	assert(target in living_enemies(), "Target must be a living enemy of this fight")
	_attack(player, target)
	_finish_player_turn()


func use_skill(skill: SkillData) -> void:
	# A guard instead of assert(), because asserts are stripped from release builds.
	if not can_use_skill(skill):
		push_error("%s cannot be used now" % skill.id)
		return
	_uses_spent[skill] = _uses_spent.get(skill, 0) + 1
	skill_used.emit(player, skill)
	for effect: EffectData in skill.effects:
		_apply_effect(effect)
	if skill.action_cost == SkillData.ActionCost.ACTION:
		_finish_player_turn()
	elif living_enemies().is_empty():
		_end(true)


func _begin_round() -> void:
	round_number += 1
	round_started.emit(round_number)


func _finish_player_turn() -> void:
	# Focus only lasts for the turn it was used in.
	_player_has_advantage = false
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
		attacker.get_attack_bonus(),
		defender.get_armor_class(),
		attacker.get_crit_threshold(),
		_spend_roll_mode(attacker)
	)
	# Off-Balance: the next attack roll after a natural 1 has disadvantage.
	if attack.is_natural_one:
		_off_balance.append(attacker)
	var damage: DamageRoll = null
	if attack.is_hit:
		damage = _resolver.roll_damage(
			attacker.get_damage_die_count(),
			attacker.get_damage_die_sides(),
			attacker.get_damage_bonus(),
			attack.is_crit,
			defender.get_damage_reduction()
		)
		defender.take_damage(damage.total)
	attack_resolved.emit(attacker, defender, attack, damage)
	# Only a natural 20 drains, not a crit in the Luck-extended range.
	if attack.is_natural_twenty:
		_drain(attacker, damage)
	if not defender.is_alive():
		combatant_defeated.emit(defender)


func _spend_roll_mode(attacker: Combatant) -> AttackRoll.RollMode:
	var mode: AttackRoll.RollMode = next_roll_mode(attacker)
	if attacker == player:
		_player_has_advantage = false
	_off_balance.erase(attacker)
	return mode


# Uses the damage rolled, before the defender's damage reduction and including overkill.
func _drain(attacker: Combatant, damage: DamageRoll) -> void:
	var drained: int = floori(damage.rolled_total / float(DRAIN_DIVISOR))
	var restored: int = attacker.heal(drained)
	attacker_drained.emit(attacker, drained, restored)


func _apply_effect(effect: EffectData) -> void:
	var heal_effect: HealEffect = effect as HealEffect
	if heal_effect != null:
		_heal_player(heal_effect)
	elif effect is AdvantageEffect:
		_player_has_advantage = true
	else:
		push_error("Effect %s has no rule for active skills" % effect.get_script().resource_path)


func _heal_player(effect: HealEffect) -> void:
	var bonus: int = player.level if effect.adds_level else 0
	var heal: HealRoll = HealRoll.new(
		_dice.roll_many(effect.die_count, effect.die_sides), effect.die_sides, bonus
	)
	var restored: int = player.heal(heal.total)
	combatant_healed.emit(player, heal, restored)


func _end(player_won: bool) -> void:
	is_over = true
	combat_ended.emit(player_won)
