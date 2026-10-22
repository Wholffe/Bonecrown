class_name EncounterRoller
extends RefCounted
## Picks the enemies of a fight room from the room table, with room scaling and elite bonuses.
## The boss room gives the boss encounter as it is.

## Rooms count from here, so the rooms of the first scaling step are unscaled.
const FIRST_ROOM: int = 1

var _dice: DiceRoller
var _table: RoomTableData


func _init(dice: DiceRoller, table: RoomTableData) -> void:
	_dice = dice
	_table = table


## Picks the encounter of the room and creates its enemies, scaled to the room.
## A room without encounters is a data error and gives no enemies.
func roll_enemies(room_number: int) -> Array[Combatant]:
	var none_excluded: Array[EncounterData] = []
	var encounter: EncounterData = pick_encounter(room_number, none_excluded)
	if encounter == null:
		var no_enemies: Array[Combatant] = []
		return no_enemies
	return create_enemies(encounter, room_number)


## Leaves out the encounters in excluded while the room's pool has others, and rolls a die only
## when more than one encounter is left. Null for a room without encounters, a data error.
func pick_encounter(room_number: int, excluded: Array[EncounterData]) -> EncounterData:
	var pool: Array[EncounterData] = _encounters_for(room_number)
	if pool.is_empty():
		push_error("The room table has no encounter for room %d" % room_number)
		return null
	var candidates: Array[EncounterData] = []
	for encounter: EncounterData in pool:
		if encounter not in excluded:
			candidates.append(encounter)
	if candidates.is_empty():
		candidates = pool
	if candidates.size() == 1:
		return candidates[0]
	return candidates[_dice.roll(candidates.size()) - 1]


## The enemies of encounter with the scaling and elite bonuses of room_number. The boss gets none.
func create_enemies(encounter: EncounterData, room_number: int) -> Array[Combatant]:
	if _is_boss_room(room_number):
		return Enemy.create_group(encounter.enemies)
	var steps: int = _scaling_steps(room_number)
	var attack_modifier: int = steps * _table.scaling_attack_bonus
	var hit_point_percent: int = steps * _table.scaling_hit_point_percent
	var name_prefix: String = ""
	if _is_elite_room(room_number):
		attack_modifier += _table.elite_attack_bonus
		hit_point_percent += _table.elite_hit_point_percent
		name_prefix = _table.elite_name_prefix
	return Enemy.create_group(encounter.enemies, attack_modifier, hit_point_percent, name_prefix)


## The room's own bonus on the loot roll after it is won.
func loot_bonus(room_number: int) -> int:
	return _table.elite_loot_bonus if _is_elite_room(room_number) else 0


func _is_elite_room(room_number: int) -> bool:
	return room_number == _table.elite_room


func _is_boss_room(room_number: int) -> bool:
	return room_number == _table.boss_room


## Empty when no tier covers the room, or when the boss room has no boss encounter.
func _encounters_for(room_number: int) -> Array[EncounterData]:
	if _is_boss_room(room_number):
		var boss_encounters: Array[EncounterData] = []
		if _table.boss_encounter != null:
			boss_encounters.append(_table.boss_encounter)
		return boss_encounters
	if _is_elite_room(room_number):
		return _table.elite_encounters
	for tier: RoomTierData in _table.tiers:
		if room_number >= tier.first_room and room_number <= tier.last_room:
			return tier.encounters
	var no_encounters: Array[EncounterData] = []
	return no_encounters


func _scaling_steps(room_number: int) -> int:
	return floori((room_number - FIRST_ROOM) / float(_table.scaling_room_step))
