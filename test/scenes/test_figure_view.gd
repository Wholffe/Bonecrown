extends GutTest
## Figure view: size, facing, the idle loop, the lunge and knockback, and the fall when defeated.

const FRAME_COUNT: int = 4
const SMALL_FRAME_SIZE: Vector2i = Vector2i(16, 16)
const TALL_FRAME_SIZE: Vector2i = Vector2i(16, 28)
const BOSS_SCALE: float = 1.5
## The lunge is halfway out after this time and back at rest well after the second one.
const MID_LUNGE_TIME: float = 0.05
const AFTER_LUNGE_TIME: float = 0.4


func _frames(frame_size: Vector2i) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for index: int in FRAME_COUNT:
		var image: Image = Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
		frames.append(ImageTexture.create_from_image(image))
	return frames


func _create_figure(frames: Array[Texture2D], faces_left: bool) -> FigureView:
	var figure: FigureView = FigureView.new()
	add_child_autofree(figure)
	figure.size = Vector2(200, FigureView.FIGURE_HEIGHT)
	figure.show_figure(frames, faces_left)
	return figure


func test_figure_shows_its_first_frame_in_a_box_of_the_common_height() -> void:
	var frames: Array[Texture2D] = _frames(SMALL_FRAME_SIZE)
	var figure: FigureView = _create_figure(frames, false)

	assert_eq(figure.shown_frame(), frames[0])
	assert_eq(figure.custom_minimum_size.y, FigureView.FIGURE_HEIGHT, "names line up below")
	assert_eq(figure.custom_minimum_size.x, SMALL_FRAME_SIZE.x * FigureView.PIXEL_SCALE)


func test_scaled_figure_towers_over_the_common_height() -> void:
	var figure: FigureView = FigureView.new()
	add_child_autofree(figure)

	figure.show_figure(_frames(TALL_FRAME_SIZE), true, BOSS_SCALE)

	assert_eq(figure.custom_minimum_size.y, TALL_FRAME_SIZE.y * FigureView.PIXEL_SCALE * BOSS_SCALE)


func test_idle_loop_steps_through_the_frames_and_wraps() -> void:
	var frames: Array[Texture2D] = _frames(SMALL_FRAME_SIZE)
	var figure: FigureView = _create_figure(frames, false)

	assert_true(figure.is_processing(), "the idle loop runs")
	simulate(figure, 1, FigureView.FRAME_DURATION)
	assert_eq(figure.shown_frame(), frames[1])
	simulate(figure, FRAME_COUNT - 1, FigureView.FRAME_DURATION)
	assert_eq(figure.shown_frame(), frames[0], "back at the first frame")


func test_figure_without_frames_shows_nothing() -> void:
	var no_frames: Array[Texture2D] = []
	var figure: FigureView = _create_figure(no_frames, false)

	assert_null(figure.shown_frame())
	assert_false(figure.is_processing())


func test_lunge_steps_toward_the_facing_side_and_returns() -> void:
	var right: FigureView = _create_figure(_frames(SMALL_FRAME_SIZE), false)
	var left: FigureView = _create_figure(_frames(SMALL_FRAME_SIZE), true)

	right.lunge()
	left.lunge()
	await wait_seconds(MID_LUNGE_TIME)
	assert_gt(right.offset_from_rest().x, 0.0, "a figure facing right lunges right")
	assert_lt(left.offset_from_rest().x, 0.0, "a figure facing left lunges left")
	await wait_seconds(AFTER_LUNGE_TIME)
	assert_eq(right.offset_from_rest(), Vector2.ZERO)
	assert_eq(left.offset_from_rest(), Vector2.ZERO)


func test_hit_knocks_the_figure_back_and_returns_it() -> void:
	var figure: FigureView = _create_figure(_frames(SMALL_FRAME_SIZE), true)

	figure.flash_hit()
	await wait_seconds(MID_LUNGE_TIME)
	assert_gt(figure.offset_from_rest().x, 0.0, "a figure facing left is pushed right")
	await wait_seconds(AFTER_LUNGE_TIME)
	assert_eq(figure.offset_from_rest(), Vector2.ZERO)


func test_defeated_figure_stops_its_idle_loop() -> void:
	var figure: FigureView = _create_figure(_frames(SMALL_FRAME_SIZE), true)

	figure.set_defeated(true)

	assert_true(figure.is_defeated())
	assert_false(figure.is_processing())
