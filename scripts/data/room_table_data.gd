class_name RoomTableData
extends Resource
## The encounters of the fight rooms by tier, the elite fights, the enemy scaling by room number and
## the boss room.

## Every fight room lies in exactly one tier.
@export var tiers: Array[RoomTierData] = []
@export_group("Elite fights")
## An elite node of the map draws from elite_encounters instead of its tier. The elite bonuses add
## to the room scaling.
@export var elite_encounters: Array[EncounterData] = []
## Put in front of the enemy name, for example "Elite Orc".
@export var elite_name_prefix: String = ""
@export var elite_hit_point_percent: int = 0
@export var elite_attack_bonus: int = 0
## Added to the loot roll after an elite fight.
@export var elite_loot_bonus: int = 0
@export_group("Scaling")
## Enemies get the scaling bonuses once more every this many rooms. The first rooms are unscaled.
@export var scaling_room_step: int = 0
@export var scaling_attack_bonus: int = 0
@export var scaling_hit_point_percent: int = 0
@export_group("Boss room")
## Draws boss_encounter without room scaling, elite bonuses or a roll.
@export var boss_room: int = 0
@export var boss_encounter: EncounterData
