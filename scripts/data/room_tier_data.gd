class_name RoomTierData
extends Resource
## Consecutive fight rooms that draw their encounter from the same pool.

## Both room numbers belong to the tier.
@export var first_room: int = 0
@export var last_room: int = 0
@export var encounters: Array[EncounterData] = []
