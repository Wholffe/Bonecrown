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
## Emitted when a boss reaches the threshold of its next phase, before its summons appear.
signal phase_started(boss: Enemy, phase: BossPhaseData)
## The summon has joined enemies and chosen its intent. It acts in the current round.
signal enemy_summoned(summon: Enemy)
## Damage without an attack roll from a skill's effect, such as a breath, a splash or a
## counter. One roll hits every target. Emitted before the defeats it causes.
signal effect_damage_dealt(
	skill: SkillData, damage: DamageRoll, die_sides: int, targets: Array[Combatant]
)
## A skill's effect cost the combatant hit points.
signal hit_points_paid(combatant: Combatant, amount: int, skill: SkillData)

enum MomentumReason { FIGHT_START, NEW_ROUND, SPENT, FENDED_OFF, KILL, DRAINED, RALLIED, SKILL }

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
	_change_momentum(
		player,
		(
			_rules.momentum_at_fight_start
			+ player.stat_modifier(StatModifierEffect.Stat.MOMENTUM_AT_FIGHT_START)
		),
		MomentumReason.FIGHT_START
	)
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


## The most Momentum the combatant can hold. Skills and items can raise the player's.
func momentum_cap_of(combatant: Combatant) -> int:
	var enemy: Enemy = combatant as Enemy
	if enemy != null:
		return enemy.momentum_cap()
	return _rules.momentum_cap + player.stat_modifier(StatModifierEffect.Stat.MOMENTUM_CAP)


func attack_cost() -> int:
	return maxi(
		(
			_rules.attack_momentum_cost
			+ player.stat_modifier(StatModifierEffect.Stat.ATTACK_MOMENTUM_COST)
		),
		0
	)


func block_cost() -> int:
	return maxi(
		(
			_rules.block_momentum_cost
			+ player.stat_modifier(StatModifierEffect.Stat.BLOCK_MOMENTUM_COST)
		),
		0
	)


func can_attack() -> bool:
	return not is_over and player.momentum >= attack_cost()


func can_block() -> bool:
	return not is_over and not _player_is_blocking and player.momentum >= block_cost()


func can_use_skill(skill: SkillData) -> bool:
	return (
		not is_over
		and skill in player.active_skills()
		and uses_left(skill) != 0
		and player.momentum >= skill.momentum_cost
		and player.hit_points > _hit_point_cost(skill)
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
	_change_momentum(player, -attack_cost(), MomentumReason.SPENT)
	_attack(player, target)
	_after_player_action()


func player_block() -> void:
	if not can_block():
		push_error("The player cannot block now")
		return
	_change_momentum(player, -block_cost(), MomentumReason.SPENT)
	_player_is_blocking = true
	player_blocked.emit(player)
	_after_player_action()


## The target is the selected enemy. Only skills with an attack effect use it.
func use_skill(skill: SkillData, target: Combatant = null) -> void:
	if not can_use_skill(skill):
		push_error("%s cannot be used now" % skill.id)
		return
	_uses_spent[skill] = _uses_spent.get(skill, 0) + 1
	_change_momentum(player, -skill.momentum_cost, MomentumReason.SPENT)
	skill_used.emit(player, skill)
	for effect: EffectData in skill.effects:
		_apply_effect(effect, skill, target)
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
			enemy_in_fight, enemy_in_fight.momentum_per_round(), MomentumReason.NEW_ROUND
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
		# A counter can defeat an enemy before its own turn comes.
		if not enemy.is_alive():
			continue
		_carry_out_intent(enemy as Enemy)
		if not player.is_alive():
			_end(false)
			return
		if living_enemies().is_empty():
			_end(true)
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
		if not player.is_alive() or not enemy.is_alive():
			return
	if intent.momentum_to_allies > 0:
		for ally: Combatant in living_enemies():
			if ally != enemy:
				_change_momentum(ally, intent.momentum_to_allies, MomentumReason.RALLIED)


## The damage passed to attack_resolved is null on a miss. The intent is null for the player, the
## skill and its effect are null for enemies and for the plain Attack.
func _attack(
	attacker: Combatant,
	defender: Combatant,
	intent: EnemyIntentData = null,
	skill: SkillData = null,
	effect: AttackEffect = null
) -> void:
	var attack: AttackRoll = _resolver.roll_attack(
		attacker.get_attack_bonus() + (effect.attack_bonus if effect != null else 0),
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
		if effect != null:
			extra_dice += effect.extra_damage_dice
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
	_after_damage(defender)
	_gain_momentum_from_attack(attacker, defender, attack, intent)
	if effect != null and attack.is_hit:
		_apply_attack_effect_on_hit(effect, skill, defender)
	if attacker != player and not attack.is_hit and _player_is_blocking:
		_retaliate(attacker)


func _after_damage(defender: Combatant) -> void:
	if not defender.is_alive():
		combatant_defeated.emit(defender)
		_defeat_summons_of(defender)
	elif defender is Enemy:
		_enter_phases(defender as Enemy)


func _apply_attack_effect_on_hit(effect: AttackEffect, skill: SkillData, target: Combatant) -> void:
	if effect.splash_die_count > 0:
		var others: Array[Combatant] = living_enemies()
		others.erase(target)
		_deal_effect_damage(skill, effect.splash_die_count, effect.splash_die_sides, others)
	var enemy: Enemy = target as Enemy
	if effect.momentum_drain > 0 and enemy != null and enemy.is_alive():
		_change_momentum(enemy, -effect.momentum_drain, MomentumReason.DRAINED)
		if enemy.intent != null and enemy.intent.momentum_cost > enemy.momentum:
			enemy.choose_intent()
			intents_announced.emit()


# Every RetaliateEffect of the player's passive skills strikes back once.
func _retaliate(attacker: Combatant) -> void:
	for skill: SkillData in player.skills:
		if skill.activation != SkillData.Activation.PASSIVE:
			continue
		for effect: EffectData in skill.effects:
			var retaliate: RetaliateEffect = effect as RetaliateEffect
			if retaliate != null and attacker.is_alive():
				var targets: Array[Combatant] = [attacker]
				_deal_effect_damage(skill, retaliate.die_count, retaliate.die_sides, targets)


## One damage roll for all targets. The player caused it, so kills give the player Momentum.
func _deal_effect_damage(
	skill: SkillData, die_count: int, die_sides: int, targets: Array[Combatant]
) -> void:
	if targets.is_empty():
		return
	var damage: DamageRoll = _resolver.roll_damage(die_count, die_sides, 0, false)
	for target: Combatant in targets:
		target.take_damage(damage.total)
	effect_damage_dealt.emit(skill, damage, die_sides, targets)
	# Summons first, because a summoner's defeat takes its summons down and reports them itself.
	for target: Combatant in targets:
		if (target as Enemy).summoner != null:
			_after_effect_damage(target)
	for target: Combatant in targets:
		if (target as Enemy).summoner == null:
			_after_effect_damage(target)


func _after_effect_damage(target: Combatant) -> void:
	_after_damage(target)
	if not target.is_alive():
		_change_momentum(player, _kill_momentum(), MomentumReason.KILL)


func _kill_momentum() -> int:
	return (
		_rules.momentum_per_kill + player.stat_modifier(StatModifierEffect.Stat.MOMENTUM_PER_KILL)
	)


func _enter_phases(boss: Enemy) -> void:
	var phase: BossPhaseData = boss.enter_next_phase()
	while phase != null:
		phase_started.emit(boss, phase)
		for summon: Combatant in Enemy.create_group(phase.summons):
			var summoned_enemy: Enemy = summon as Enemy
			summoned_enemy.summoner = boss
			summoned_enemy.choose_intent()
			enemies.append(summoned_enemy)
			enemy_summoned.emit(summoned_enemy)
		# The intent announced at the start of the round may not exist in the new phase.
		boss.choose_intent()
		intents_announced.emit()
		phase = boss.enter_next_phase()


func _defeat_summons_of(summoner: Combatant) -> void:
	for enemy: Combatant in living_enemies():
		if (enemy as Enemy).summoner == summoner:
			enemy.take_damage(enemy.hit_points)
			combatant_defeated.emit(enemy)


func _gain_momentum_from_attack(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, intent: EnemyIntentData
) -> void:
	if attacker == player:
		if not defender.is_alive():
			_change_momentum(player, _kill_momentum(), MomentumReason.KILL)
	elif not attack.is_hit:
		_change_momentum(
			player,
			(
				_rules.momentum_per_fended_attack
				+ player.stat_modifier(StatModifierEffect.Stat.MOMENTUM_PER_FENDED_ATTACK)
			),
			MomentumReason.FENDED_OFF
		)
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
	var before: int = combatant.momentum
	combatant.momentum = clampi(before + change, 0, momentum_cap_of(combatant))
	if combatant.momentum != before:
		momentum_changed.emit(combatant, combatant.momentum, combatant.momentum - before, reason)


# Uses the damage rolled, before the defender's damage reduction and including overkill.
func _drain(attacker: Combatant, damage: DamageRoll) -> void:
	var drained: int = floori(damage.rolled_total / float(DRAIN_DIVISOR))
	var restored: int = attacker.heal(drained)
	attacker_drained.emit(attacker, drained, restored)


func _apply_effect(effect: EffectData, skill: SkillData, target: Combatant) -> void:
	if effect is HealEffect:
		_heal_player(effect as HealEffect, skill)
	elif effect is AdvantageEffect:
		_player_has_advantage = true
	elif effect is AttackEffect:
		assert(target in living_enemies(), "An attack skill needs a living enemy as target")
		_attack(player, target, null, skill, effect as AttackEffect)
	elif effect is AreaDamageEffect:
		var area: AreaDamageEffect = effect as AreaDamageEffect
		_deal_effect_damage(skill, area.die_count, area.die_sides, living_enemies())
	elif effect is MomentumGainEffect:
		_gain_momentum_from_skill(effect as MomentumGainEffect, skill)
	else:
		push_error("Effect %s has no rule for active skills" % effect.get_script().resource_path)


func _gain_momentum_from_skill(effect: MomentumGainEffect, skill: SkillData) -> void:
	if effect.hit_point_cost > 0:
		player.take_damage(effect.hit_point_cost)
		hit_points_paid.emit(player, effect.hit_point_cost, skill)
	_change_momentum(player, effect.amount, MomentumReason.SKILL)


func _hit_point_cost(skill: SkillData) -> int:
	var cost: int = 0
	for effect: EffectData in skill.effects:
		var gain: MomentumGainEffect = effect as MomentumGainEffect
		if gain != null:
			cost += gain.hit_point_cost
	return cost


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
