class_name BattlefieldView
extends MarginContainer
## The battle's backdrop in pixel art: a dungeon wall along the top and a tiled floor below it,
## drawn behind the combatants.

const FLOOR_TILES: Array[Texture2D] = [
	preload("res://assets/sprites/dungeon/floor_1.png"),
	preload("res://assets/sprites/dungeon/floor_2.png"),
	preload("res://assets/sprites/dungeon/floor_3.png"),
]
## Indexes into FLOOR_TILES, walked diagonally, so the plain tile dominates without a visible grid.
const FLOOR_PATTERN: Array[int] = [0, 0, 1, 0, 0, 2, 0]
const WALL_TOP_TILE: Texture2D = preload("res://assets/sprites/dungeon/wall_top_mid.png")
const WALL_TILE: Texture2D = preload("res://assets/sprites/dungeon/wall_mid.png")
const BANNER_TILE: Texture2D = preload("res://assets/sprites/dungeon/wall_banner_red.png")
## Every pixel of the art becomes this many pixels on screen.
const PIXEL_SCALE: float = 3.0
const TILE_PIXELS: float = 16.0
## The wall is two tiles high: its top edge and its face.
const WALL_ROWS: int = 2
## A banner hangs on every this many wall tiles, starting at BANNER_OFFSET.
const BANNER_SPACING: int = 5
const BANNER_OFFSET: int = 2
## Shows through the open top of the wall tiles, as the darkness above the wall.
const BACKDROP_COLOR: Color = Color(0.07, 0.06, 0.08)
## Darkened, so the text in front of it stays readable.
const FLOOR_MODULATE: Color = Color(0.5, 0.5, 0.55)
const WALL_MODULATE: Color = Color(0.75, 0.75, 0.8)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var tile_size: float = TILE_PIXELS * PIXEL_SCALE
	var columns: int = ceili(size.x / tile_size)
	var rows: int = ceili(size.y / tile_size)
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR)
	for column: int in columns:
		_draw_tile(WALL_TOP_TILE, column, 0, WALL_MODULATE)
		var is_banner: bool = column % BANNER_SPACING == BANNER_OFFSET
		_draw_tile(BANNER_TILE if is_banner else WALL_TILE, column, 1, WALL_MODULATE)
		for row: int in range(WALL_ROWS, rows):
			var pattern_index: int = (column * 3 + row * 5) % FLOOR_PATTERN.size()
			_draw_tile(FLOOR_TILES[FLOOR_PATTERN[pattern_index]], column, row, FLOOR_MODULATE)


func _draw_tile(texture: Texture2D, column: int, row: int, tint: Color) -> void:
	var tile_size: float = TILE_PIXELS * PIXEL_SCALE
	var rect: Rect2 = Rect2(Vector2(column, row) * tile_size, Vector2(tile_size, tile_size))
	draw_texture_rect(texture, rect, false, tint)
