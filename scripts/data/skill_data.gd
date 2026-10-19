class_name SkillData
extends Resource
## Data of a skill: how it is activated and which effects it applies.

# Stored as numbers in .tres files: append new members, never renumber.
# UNSET is the default, so every real value is written to the .tres explicitly.
enum Activation { PASSIVE = 0, ACTIVE = 1, UNSET = -1 }
enum ActionCost { ACTION = 0, FREE = 1, UNSET = -1 }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var activation: Activation = Activation.UNSET
## Only for active skills. ACTION ends the player's turn, FREE does not.
@export var action_cost: ActionCost = ActionCost.UNSET
## Only for active skills. 0 means no limit.
@export var uses_per_fight: int = 0
@export var effects: Array[EffectData] = []
## Taken skills only come back in offers when they are stackable.
@export var stackable: bool = false
## Lowest character level at which the skill can be offered. 0 means from the start.
@export var min_level: int = 0
