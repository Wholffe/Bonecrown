class_name TurnBanner
extends Control
## A large banner in the middle of the battle that announces whose turn it is.

const YOUR_TURN_TEXT: String = "Your Turn"
const ENEMY_TURN_TEXT: String = "Enemy Turn"
const OUT_OF_MOMENTUM_TEXT: String = "Out of Momentum"
const YOUR_TURN_COLOR: Color = Color(1.0, 0.85, 0.35)
const ENEMY_TURN_COLOR: Color = Color(1.0, 0.45, 0.35)
const OUT_OF_MOMENTUM_COLOR: Color = Color(0.75, 0.75, 0.8)
const FADE_DURATION: float = 0.12
## Long enough to read, short enough not to slow down every turn.
const HOLD_DURATION: float = 0.55

## Tests and a later fast mode turn the animations off; the banner then only records its text.
var animations_enabled: bool = true
var _last_text: String = ""
var _tween: Tween

@onready var _label: Label = %BannerLabel


func _ready() -> void:
	hide()


## Shows the text, holds it and fades out. Await it to pause the battle playback meanwhile.
## A new text replaces one that is still showing.
func play(text: String, color: Color) -> void:
	_last_text = text
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	if not animations_enabled:
		return
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	_tween.tween_interval(HOLD_DURATION)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_tween.finished.connect(hide)
	await _tween.finished


func last_text() -> String:
	return _last_text
