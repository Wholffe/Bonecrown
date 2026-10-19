class_name Combat
extends RefCounted
## Turn-based fight: the player acts first, then every living enemy. Reports each step via signals.

signal round_started(round_number: int)
signal attack_resolved(
	attacker: Combatant, defender: Combatant, attack: AttackRoll, damage: DamageRoll
)
signal combatant_defeated(combatant: Combatant)
signal combat_ended(player_won: bool)

var player: Combatant
var enemies: Array[Combatant] = []
var round_number: int = 0
var is_over: bool = false
var _resolver: AttackResolver


func _init(fight_player: Combatant, fight_enemies: Array[Combatant], dice: DiceRoller) -> void:
	assert(not fight_enemies.is_empty(), "A fight needs at least one enemy")
	player = fight_player
	enemies = fight_enemies
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


func player_attack(target: Combatant) -> void:
	assert(not is_over, "The fight is already over")
	assert(target in living_enemies(), "Target must be a living enemy of this fight")
	_attack(player, target)
	if living_enemies().is_empty():
		_end(true)
		return
	for enemy: Combatant in living_enemies():
		_attack(enemy, player)
		if not player.is_alive():
			_end(false)
			return
	_begin_round()


func _begin_round() -> void:
	round_number += 1
	round_started.emit(round_number)


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


func _end(player_won: bool) -> void:
	is_over = true
	combat_ended.emit(player_won)
