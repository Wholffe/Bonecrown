extends GutTest

const WARNING_LEVEL_ERROR: int = 2


func test_viewport_is_1280_by_720() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)


func test_untyped_declarations_are_errors() -> void:
	assert_eq(
		ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"),
		WARNING_LEVEL_ERROR
	)


func test_inferred_declarations_are_errors() -> void:
	assert_eq(
		ProjectSettings.get_setting("debug/gdscript/warnings/inferred_declaration"),
		WARNING_LEVEL_ERROR
	)
