class_name Combat
extends RefCounted
## Turn-based fight with Momentum: the player spends it on actions until the turn ends, then every
## living enemy carries out its announced intent. Reports each step via signals.

signal round_started(round_number: int)
signal attack_resolved(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
)
signal skill_used(user: Combatant, skill: SkillData)
## The skill names the source of the heal.
signal combatant_healed(combatant: Combatant, heal: HealRoll, restored: int, skill: SkillData)
## A natural 20 heals the attacker for half the damage rolled. Emitted right after attack_resolved.
signal attacker_drained(attacker: Combatant, drained: int, restored: int)
signal combatant_defeated(combatant: Combatant)
signal combat_ended(player_won: bool)
## Emitted for every change, with the new value and the change (negative when spent or lost).
signal momentum_changed(
	combatant: Combatant, momentum: int, change: int, reason: Combat.MomentumReason
)
## Emitted after every living enemy has chosen its intent for the new round.
signal intents_announced
signal player_blocked(player: Character)
## Emitted when an enemy starts to carry out its intent, before its attacks.
signal intent_started(enemy: Enemy, intent: EnemyIntentData)
signal player_turn_ended

enum MomentumReason { FIGHT_START, NEW_ROUND, SPENT, FENDED_OFF, KILL, DRAINED, RALLIED }

const UNLIMITED_USES: int = -1
## Drain heals the damage rolled divided by this, rounded down.
const DRAIN_DIVISOR: int = 2

var player: Character
var enemies: Array[Combatant] = []
var round_number: int = 0
var is_over: bool = false
var _dice: DiceRoller
var _resolver: AttackResolver
var _rules: GameRulesData
var _uses_spent: Dictionary[SkillData, int] = {}
## Set by an advantage effect such as Focus, spent on the player's next attack this turn.
var _player_has_advantage: bool = false
## Combatants whose last attack roll was a natural 1: their next one has disadvantage.
var _off_balance: Array[Combatant] = []
## Block lasts until the player's next turn: attacks against the player have disadvantage.
var _player_is_blocking: bool = false


func _init(
	fight_player: Character, fight_enemies: Array[Combatant], dice: DiceRoller, rules: GameRulesData
) -> void:
	assert(not fight_enemies.is_empty(), "A fight needs at least one enemy")
	player = fight_player
	enemies = fight_enemies
	_dice = dice
	_rules = rules
	_resolver = AttackResolver.new(dice)


## Separate from _init, so listeners can connect before the first round starts.
func start() -> void:
	player.momentum = 0
	_change_momentum(player, _rules.momentum_at_fight_start, MomentumReason.FIGHT_START)
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
	# Enemies only ever attack the player, so a block always applies to them.
	var has_disadvantage: bool = (
		combatant in _off_balance or (combatant != player and _player_is_blocking)
	)
	# Advantage and disadvantage cancel each other out (5e).
	if has_advantage == has_disadvantage:
		return AttackRoll.RollMode.NORMAL
	if has_advantage:
		return AttackRoll.RollMode.ADVANTAGE
	return AttackRoll.RollMode.DISADVANTAGE


func is_player_blocking() -> bool:
	return _player_is_blocking


func can_attack() -> bool:
	return not is_over and player.momentum >= _rules.attack_momentum_cost


func can_block() -> bool:
	return not is_over and not _player_is_blocking and player.momentum >= _rules.block_momentum_cost


func can_use_skill(skill: SkillData) -> bool:
	return (
		not is_over
		and skill in player.active_skills()
		and uses_left(skill) != 0
		and player.momentum >= skill.momentum_cost
	)


## False once the player cannot pay for anything, which ends the turn on its own.
func has_affordable_action() -> bool:
	if can_attack() or can_block():
		return true
	for skill: SkillData in player.active_skills():
		if can_use_skill(skill):
			return true
	return false


func player_attack(target: Combatant) -> void:
	# Guards instead of assert(), because asserts are stripped from release builds.
	if not can_attack():
		push_error("The player cannot attack now")
		return
	assert(target in living_enemies(), "Target must be a living enemy of this fight")
	_change_momentum(player, -_rules.attack_momentum_cost, MomentumReason.SPENT)
	_attack(player, target)
	_after_player_action()


func player_block() -> void:
	if not can_block():
		push_error("The player cannot block now")
		return
	_change_momentum(player, -_rules.block_momentum_cost, MomentumReason.SPENT)
	_player_is_blocking = true
	player_blocked.emit(player)
	_after_player_action()


func use_skill(skill: SkillData) -> void:
	if not can_use_skill(skill):
		push_error("%s cannot be used now" % skill.id)
		return
	_uses_spent[skill] = _uses_spent.get(skill, 0) + 1
	_change_momentum(player, -skill.momentum_cost, MomentumReason.SPENT)
	skill_used.emit(player, skill)
	for effect: EffectData in skill.effects:
		_apply_effect(effect, skill)
	_after_player_action()


## Unused Momentum carries over into the next round, up to the cap.
func end_turn() -> void:
	if is_over:
		push_error("The fight is already over")
		return
	_finish_player_turn()


func _begin_round() -> void:
	round_number += 1
	_player_is_blocking = false
	round_started.emit(round_number)
	if round_number > 1:
		_change_momentum(player, _rules.momentum_per_round, MomentumReason.NEW_ROUND)
	for enemy: Combatant in living_enemies():
		var enemy_in_fight: Enemy = enemy as Enemy
		_change_momentum(
			enemy_in_fight, enemy_in_fight.data.momentum_per_round, MomentumReason.NEW_ROUND
		)
		enemy_in_fight.choose_intent()
	intents_announced.emit()


func _after_player_action() -> void:
	if living_enemies().is_empty():
		_end(true)
	elif not has_affordable_action():
		_finish_player_turn()


func _finish_player_turn() -> void:
	# Focus only lasts for the turn it was used in.
	_player_has_advantage = false
	player_turn_ended.emit()
	for enemy: Combatant in living_enemies():
		_carry_out_intent(enemy as Enemy)
		if not player.is_alive():
			_end(false)
			return
	_begin_round()


func _carry_out_intent(enemy: Enemy) -> void:
	var intent: EnemyIntentData = enemy.intent
	if intent == null:
		# Enemy data without intents attacks once and has no Momentum to spend.
		_attack(enemy, player)
		return
	_change_momentum(enemy, -intent.momentum_cost, MomentumReason.SPENT)
	intent_started.emit(enemy, intent)
	for _i: int in intent.attack_count:
		_attack(enemy, player, intent)
		if not player.is_alive():
			return
	if intent.momentum_to_allies > 0:
		for ally: Combatant in living_enemies():
			if ally != enemy:
				_change_momentum(ally, intent.momentum_to_allies, MomentumReason.RALLIED)


## The damage passed to attack_resolved is null on a miss. The intent is null for the player.
func _attack(attacker: Combatant, defender: Combatant, intent: EnemyIntentData = null) -> void:
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
		var extra_dice: int = intent.extra_damage_dice if intent != null else 0
		damage = _resolver.roll_damage(
			attacker.get_damage_die_count() + extra_dice,
			attacker.get_damage_die_sides(),
			attacker.get_damage_bonus(),
			attack.is_crit and not defender.is_crit_resistant(),
			defender.get_damage_reduction()
		)
		defender.take_damage(damage.total)
	attack_resolved.emit(attacker, defender, attack, damage)
	# Only a natural 20 drains, not a crit in the Luck-extended range.
	if attack.is_natural_twenty:
		_drain(attacker, damage)
	if not defender.is_alive():
		combatant_defeated.emit(defender)
	_gain_momentum_from_attack(attacker, defender, attack, intent)


func _gain_momentum_from_attack(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, intent: EnemyIntentData
) -> void:
	if attacker == player:
		if not defender.is_alive():
			_change_momentum(player, _rules.momentum_per_kill, MomentumReason.KILL)
	elif not attack.is_hit:
		_change_momentum(player, _rules.momentum_per_fended_attack, MomentumReason.FENDED_OFF)
	elif intent != null and intent.momentum_drain > 0:
		_change_momentum(player, -intent.momentum_drain, MomentumReason.DRAINED)


func _spend_roll_mode(attacker: Combatant) -> AttackRoll.RollMode:
	var mode: AttackRoll.RollMode = next_roll_mode(attacker)
	if attacker == player:
		_player_has_advantage = false
	_off_balance.erase(attacker)
	return mode


## Keeps Momentum between 0 and the combatant's cap and reports only real changes.
func _change_momentum(combatant: Combatant, change: int, reason: MomentumReason) -> void:
	var cap: int = _rules.momentum_cap
	var enemy: Enemy = combatant as Enemy
	if enemy != null:
		cap = enemy.data.momentum_cap
	var before: int = combatant.momentum
	combatant.momentum = clampi(before + change, 0, cap)
	if combatant.momentum != before:
		momentum_changed.emit(combatant, combatant.momentum, combatant.momentum - before, reason)


# Uses the damage rolled, before the defender's damage reduction and including overkill.
func _drain(attacker: Combatant, damage: DamageRoll) -> void:
	var drained: int = floori(damage.rolled_total / float(DRAIN_DIVISOR))
	var restored: int = attacker.heal(drained)
	attacker_drained.emit(attacker, drained, restored)


func _apply_effect(effect: EffectData, skill: SkillData) -> void:
	var heal_effect: HealEffect = effect as HealEffect
	if heal_effect != null:
		_heal_player(heal_effect, skill)
	elif effect is AdvantageEffect:
		_player_has_advantage = true
	else:
		push_error("Effect %s has no rule for active skills" % effect.get_script().resource_path)


func _heal_player(effect: HealEffect, skill: SkillData) -> void:
	var bonus: int = player.level if effect.adds_level else 0
	var heal: HealRoll = HealRoll.new(
		_dice.roll_many(effect.die_count, effect.die_sides), effect.die_sides, bonus
	)
	var restored: int = player.heal(heal.total)
	combatant_healed.emit(player, heal, restored, skill)


func _end(player_won: bool) -> void:
	is_over = true
	combat_ended.emit(player_won)
