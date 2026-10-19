class_name WeaponData
extends ItemData
## Weapon slot item: the damage dice rolled on a hit.

@export var damage_die_count: int = 0
@export var damage_die_sides: int = 0


func get_slot() -> Slot:
	return Slot.WEAPON
