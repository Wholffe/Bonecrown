class_name MapTableData
extends Resource
## How the map of a run is drawn: lanes and paths, the node types of the open rows with their
## weights and first rows, the fixed rest row before the boss and the checks on sealed treasure.

## Columns the paths move in. Rows with a single node sit in the middle.
@export var lane_count: int = 0
## Paths from the first fight to the rest before the boss. They may meet and split again.
@export var path_count: int = 0
## Row of the rest site before the boss. The rows between the first fight and it are open rows.
@export var rest_row: int = 0
@export_group("Node weights")
@export var fight_weight: int = 0
@export var elite_weight: int = 0
@export var merchant_weight: int = 0
@export var rest_weight: int = 0
@export var treasure_weight: int = 0
@export_group("First rows")
## The first open row a node type may appear in. Fights may appear anywhere.
@export var elite_first_row: int = 0
@export var merchant_first_row: int = 0
@export var rest_first_row: int = 0
@export var treasure_first_row: int = 0
@export_group("Sealed treasure")
## Chance that a treasure node is sealed behind a skill check.
@export var sealed_treasure_chance_percent: int = 0
@export var skill_checks: Array[SkillCheckData] = []
