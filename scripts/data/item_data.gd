@abstract class_name ItemData
extends Resource
## Base data of an equippable item. Each subclass stands for one equipment slot.

enum Slot { WEAPON, ARMOR, TALISMAN }
# Stored as numbers in .tres files: append new members, never renumber.
# UNSET is the default, so every real value is written to the .tres explicitly.
enum Rarity { COMMON = 0, UNCOMMON = 1, RARE = 2, LEGENDARY = 3, UNSET = -1 }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Required for items in the loot table. Starting items stay UNSET.
@export var rarity: Rarity = Rarity.UNSET
## Passive effects while the item is worn, the same building blocks that skills use.
@export var effects: Array[EffectData] = []

# The slot follows from the subclass, so it can never contradict the item's fields.
@abstract func get_slot() -> Slot
