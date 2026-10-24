class_name EncounterRoller
extends RefCounted
## Picks the enemies of a fight from the room table, with room scaling and, for an elite fight,
## the elite bonuses. The boss room gives the boss encounter as it is.

## Rooms count from here, so the rooms of the first scaling step are unscaled.
const FIRST_ROOM: int = 1

var _dice: DiceRoller
var _table: RoomTableData


func _init(dice: DiceRoller, table: RoomTableData) -> void:
	_dice = dice
	_table = table


## Picks the encounter of the room and creates its enemies, scaled to the room.
## A room without encounters is a data error and gives no enemies.
func roll_enemies(room_number: int, is_elite: bool = false) -> Array[Combatant]:
	var encounter: EncounterData = pick_encounter(room_number, is_elite)
	if encounter == null:
		var no_enemies: Array[Combatant] = []
		return no_enemies
	return create_enemies(encounter, room_number, is_elite)


## Rolls a die only when the pool holds more than one encounter. Null for a room without
## encounters, a data error.
func pick_encounter(room_number: int, is_elite: bool = false) -> EncounterData:
	var pool: Array[EncounterData] = _encounters_for(room_number, is_elite)
	if pool.is_empty():
		push_error("The room table has no encounter for room %d" % room_number)
		return null
	if pool.size() == 1:
		return pool[0]
	return pool[_dice.roll(pool.size()) - 1]


## The enemies of encounter with the scaling of room_number and, for an elite fight, the elite
## bonuses. The boss gets none.
func create_enemies(
	encounter: EncounterData, room_number: int, is_elite: bool = false
) -> Array[Combatant]:
	if _is_boss_room(room_number):
		return Enemy.create_group(encounter.enemies)
	var steps: int = _scaling_steps(room_number)
	var attack_modifier: int = steps * _table.scaling_attack_bonus
	var hit_point_percent: int = steps * _table.scaling_hit_point_percent
	var name_prefix: String = ""
	if is_elite:
		attack_modifier += _table.elite_attack_bonus
		hit_point_percent += _table.elite_hit_point_percent
		name_prefix = _table.elite_name_prefix
	return Enemy.create_group(encounter.enemies, attack_modifier, hit_point_percent, name_prefix)


## The fight's own bonus on the loot roll after it is won.
func loot_bonus(is_elite: bool) -> int:
	return _table.elite_loot_bonus if is_elite else 0


func _is_boss_room(room_number: int) -> bool:
	return room_number == _table.boss_room


## Empty when no tier covers the room, or when the boss room has no boss encounter.
func _encounters_for(room_number: int, is_elite: bool) -> Array[EncounterData]:
	if _is_boss_room(room_number):
		var boss_encounters: Array[EncounterData] = []
		if _table.boss_encounter != null:
			boss_encounters.append(_table.boss_encounter)
		return boss_encounters
	if is_elite:
		return _table.elite_encounters
	for tier: RoomTierData in _table.tiers:
		if room_number >= tier.first_room and room_number <= tier.last_room:
			return tier.encounters
	var no_encounters: Array[EncounterData] = []
	return no_encounters


func _scaling_steps(room_number: int) -> int:
	return floori((room_number - FIRST_ROOM) / float(_table.scaling_room_step))
