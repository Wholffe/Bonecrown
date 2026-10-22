extends GutTest
## Turn banner: shows the text in its color and pauses the playback only when animated.

const TURN_BANNER_SCENE: PackedScene = preload("res://scenes/ui/turn_banner.tscn")


func _create_banner(animated: bool) -> TurnBanner:
	var banner: TurnBanner = TURN_BANNER_SCENE.instantiate() as TurnBanner
	banner.animations_enabled = animated
	add_child_autofree(banner)
	return banner


func test_banner_starts_hidden() -> void:
	var banner: TurnBanner = _create_banner(true)

	assert_false(banner.visible)


func test_play_without_animations_records_the_text_and_stays_hidden() -> void:
	var banner: TurnBanner = _create_banner(false)

	await banner.play(TurnBanner.ENEMY_TURN_TEXT, TurnBanner.ENEMY_TURN_COLOR)

	assert_eq(banner.last_text(), TurnBanner.ENEMY_TURN_TEXT)
	assert_false(banner.visible)


func test_animated_play_shows_the_banner_until_it_has_faded() -> void:
	var banner: TurnBanner = _create_banner(true)

	banner.play(TurnBanner.YOUR_TURN_TEXT, TurnBanner.YOUR_TURN_COLOR)

	assert_true(banner.visible)
	var label: Label = banner.get_node("%BannerLabel") as Label
	assert_eq(label.text, TurnBanner.YOUR_TURN_TEXT)
	assert_eq(label.get_theme_color("font_color"), TurnBanner.YOUR_TURN_COLOR)
	await wait_seconds(TurnBanner.HOLD_DURATION + 3 * TurnBanner.FADE_DURATION)
	assert_false(banner.visible)
