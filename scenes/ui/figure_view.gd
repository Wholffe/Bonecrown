class_name FigureView
extends Control
## A combatant's pixel-art figure in the battle: an idle loop, a lunge when it attacks, a red flash
## and a knockback when it is hit, and a fall when it is defeated.

## Every pixel of the art becomes this many pixels on screen.
const PIXEL_SCALE: float = 5.0
## Every figure stands in a box at least this tall, so the names below the figures line up. It
## fits the tallest regular art, 28 pixels high.
const FIGURE_HEIGHT: float = 140.0
const FRAME_DURATION: float = 0.15
const LUNGE_DISTANCE: float = 28.0
const LUNGE_OUT_DURATION: float = 0.07
const LUNGE_BACK_DURATION: float = 0.14
const KNOCKBACK_DISTANCE: float = 10.0
const HIT_FLASH_COLOR: Color = Color(1.0, 0.25, 0.25)
const HIT_FLASH_DURATION: float = 0.3
const FALL_DEGREES: float = 90.0
const FALL_DURATION: float = 0.3

var _frames: Array[Texture2D] = []
var _frame_index: int = 0
var _frame_time: float = 0.0
var _faces_left: bool = false
var _is_defeated: bool = false
var _rest_position: Vector2 = Vector2.ZERO
var _sprite: TextureRect = TextureRect.new()
var _motion_tween: Tween
var _flash_tween: Tween
var _fall_tween: Tween


# Created here, so the card can show a figure before this node enters the tree.
func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, FIGURE_HEIGHT)
	_sprite.name = "Sprite"
	_sprite.mouse_filter = MOUSE_FILTER_IGNORE
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_sprite()


func _process(delta: float) -> void:
	_frame_time += delta
	while _frame_time >= FRAME_DURATION:
		_frame_time -= FRAME_DURATION
		_frame_index = (_frame_index + 1) % _frames.size()
	_sprite.texture = _frames[_frame_index]


## The frames face right. A figure that faces left is mirrored.
func show_figure(frames: Array[Texture2D], faces_left: bool, figure_scale: float = 1.0) -> void:
	_frames = frames
	_faces_left = faces_left
	_frame_index = 0
	_frame_time = 0.0
	_sprite.flip_h = faces_left
	_sprite.visible = not frames.is_empty()
	if frames.is_empty():
		_sprite.texture = null
		set_process(false)
		return
	_sprite.texture = frames[0]
	_sprite.size = frames[0].get_size() * PIXEL_SCALE * figure_scale
	custom_minimum_size = Vector2(_sprite.size.x, maxf(FIGURE_HEIGHT, _sprite.size.y))
	_place_sprite()
	set_process(frames.size() > 1 and not _is_defeated)


func shown_frame() -> Texture2D:
	return _sprite.texture


func is_facing_left() -> bool:
	return _faces_left


## How far the figure is from its resting place, for tests.
func offset_from_rest() -> Vector2:
	return _sprite.position - _rest_position


## A quick step toward the side the figure faces and back.
func lunge() -> void:
	_move_and_return(Vector2(-LUNGE_DISTANCE if _faces_left else LUNGE_DISTANCE, 0.0))


## A red flash and a short knockback away from the side the figure faces.
func flash_hit() -> void:
	_move_and_return(Vector2(KNOCKBACK_DISTANCE if _faces_left else -KNOCKBACK_DISTANCE, 0.0))
	if _flash_tween != null:
		_flash_tween.kill()
	_sprite.modulate = HIT_FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, HIT_FLASH_DURATION)


## A defeated figure stops its idle loop and falls on its back.
func set_defeated(value: bool) -> void:
	if value == _is_defeated:
		return
	_is_defeated = value
	set_process(_frames.size() > 1 and not value)
	if _fall_tween != null:
		_fall_tween.kill()
	var fallen_degrees: float = FALL_DEGREES if _faces_left else -FALL_DEGREES
	if not value:
		_sprite.rotation_degrees = 0.0
		return
	_fall_tween = create_tween()
	_fall_tween.tween_property(_sprite, "rotation_degrees", fallen_degrees, FALL_DURATION)


func is_defeated() -> bool:
	return _is_defeated


# The figure stands at the bottom center and falls around its feet.
func _place_sprite() -> void:
	if _motion_tween != null:
		_motion_tween.kill()
	_rest_position = Vector2((size.x - _sprite.size.x) / 2.0, size.y - _sprite.size.y)
	_sprite.position = _rest_position
	_sprite.pivot_offset = Vector2(_sprite.size.x / 2.0, _sprite.size.y)


func _move_and_return(offset: Vector2) -> void:
	if _motion_tween != null:
		_motion_tween.kill()
	_sprite.position = _rest_position
	_motion_tween = create_tween()
	_motion_tween.tween_property(_sprite, "position", _rest_position + offset, LUNGE_OUT_DURATION)
	_motion_tween.tween_property(_sprite, "position", _rest_position, LUNGE_BACK_DURATION)
