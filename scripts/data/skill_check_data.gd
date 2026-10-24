class_name SkillCheckData
extends Resource
## A d20 + attribute bonus check against a difficulty that guards a node, such as a sealed chest.

@export var id: StringName
@export var display_name: String
## What the player tries, for the button: "Force the rusted lock".
@export var action_text: String
@export var attribute: Attributes.Kind = Attributes.Kind.UNSET
## The total of d20 + attribute bonus must reach it.
@export var difficulty: int = 0
## Hit points lost on a failed check.
@export var fail_damage: int = 0
