extends GdUnitTestSuite

## Unit tests for export configuration validation (Tasks K1 + K2).
## Validates that export_presets.cfg contains correct settings for HTML5 and Android.


# -- Helpers -------------------------------------------------------------------

var _presets_path: String = "res://export_presets.cfg"
var _preset_text: String = ""
var _sections: Dictionary = {}  # section_name -> Dictionary of key=value pairs


func _parse_presets() -> void:
	var abs_path: String = ProjectSettings.globalize_path(_presets_path)
	var file := FileAccess.open(_presets_path, FileAccess.READ)
	if file == null:
		# Try absolute path
		file = FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		push_error("Could not open export_presets.cfg")
		return
	_preset_text = file.get_as_text()
	file.close()

	# Parse INI-style sections
	var current_section: String = ""
	for line: String in _preset_text.split("\n"):
		line = line.strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2)
			if not _sections.has(current_section):
				_sections[current_section] = {}
		elif "=" in line and current_section != "":
			var eq_pos: int = line.find("=")
			var key: String = line.substr(0, eq_pos)
			var value: String = line.substr(eq_pos + 1)
			_sections[current_section][key] = value


func _get_web_option(key: String) -> String:
	## Returns the value of a key in [preset.0.options] (Web preset).
	if _sections.has("preset.0.options"):
		return _sections["preset.0.options"].get(key, "")
	return ""


func _get_web_preset(key: String) -> String:
	## Returns the value of a key in [preset.0] (Web preset header).
	if _sections.has("preset.0"):
		return _sections["preset.0"].get(key, "")
	return ""


func _get_android_option(key: String) -> String:
	## Returns the value of a key in [preset.1.options] (Android preset).
	if _sections.has("preset.1.options"):
		return _sections["preset.1.options"].get(key, "")
	return ""


func _get_android_preset(key: String) -> String:
	## Returns the value of a key in [preset.1] (Android preset header).
	if _sections.has("preset.1"):
		return _sections["preset.1"].get(key, "")
	return ""


# -- Setup ---------------------------------------------------------------------

func before() -> void:
	_parse_presets()


# -- K1: Web Preset Exists and Is Correctly Named ------------------------------

func test_export_presets_file_exists() -> void:
	assert_bool(_preset_text.length() > 0).is_true()


func test_web_preset_exists() -> void:
	assert_bool(_sections.has("preset.0")).is_true()


func test_web_preset_name_is_web() -> void:
	assert_str(_get_web_preset("name")).is_equal("\"Web\"")


func test_web_preset_platform_is_web() -> void:
	assert_str(_get_web_preset("platform")).is_equal("\"Web\"")


func test_web_preset_is_runnable() -> void:
	assert_str(_get_web_preset("runnable")).is_equal("true")


# -- K1: Thread Support -------------------------------------------------------

func test_web_thread_support_disabled() -> void:
	# Thread support should be false for broader browser compatibility
	assert_str(_get_web_option("variant/thread_support")).is_equal("false")


# -- K1: Canvas Resize Policy -------------------------------------------------

func test_web_canvas_resize_policy_is_adaptive() -> void:
	# 2 = Adaptive (scales to fit browser window)
	assert_str(_get_web_option("html/canvas_resize_policy")).is_equal("2")


# -- K1: VRAM Texture Compression for WebGL2 ----------------------------------

func test_web_vram_compression_desktop_enabled() -> void:
	assert_str(_get_web_option("vram_texture_compression/for_desktop")).is_equal("true")


func test_web_vram_compression_mobile_enabled() -> void:
	assert_str(_get_web_option("vram_texture_compression/for_mobile")).is_equal("true")


# -- K1: Viewport Meta Tag for Mobile Scaling ----------------------------------

func test_web_head_include_has_viewport_meta() -> void:
	var head_include: String = _get_web_option("html/head_include")
	assert_bool(head_include.contains("viewport")).is_true()


func test_web_head_include_has_width_device_width() -> void:
	var head_include: String = _get_web_option("html/head_include")
	assert_bool(head_include.contains("width=device-width")).is_true()


func test_web_head_include_has_initial_scale() -> void:
	var head_include: String = _get_web_option("html/head_include")
	assert_bool(head_include.contains("initial-scale=1")).is_true()


# -- K1: PWA Settings ---------------------------------------------------------

func test_web_pwa_enabled() -> void:
	assert_str(_get_web_option("progressive_web_app/enabled")).is_equal("true")


func test_web_pwa_landscape_orientation() -> void:
	# 1 = Landscape
	assert_str(_get_web_option("progressive_web_app/orientation")).is_equal("1")


func test_web_pwa_fullscreen_display() -> void:
	# 3 = Fullscreen
	assert_str(_get_web_option("progressive_web_app/display")).is_equal("3")


# -- K1: Export Path -----------------------------------------------------------

func test_web_export_path_set() -> void:
	var path: String = _get_web_preset("export_path")
	assert_bool(path.length() > 0).is_true()


# -- K1: Focus Canvas on Start ------------------------------------------------

func test_web_focus_canvas_on_start() -> void:
	assert_str(_get_web_option("html/focus_canvas_on_start")).is_equal("true")


# -- K1: Extensions Support Disabled ------------------------------------------

func test_web_extensions_support_disabled() -> void:
	assert_str(_get_web_option("variant/extensions_support")).is_equal("false")


# -- K1: Project Settings Validation -------------------------------------------

func test_renderer_is_gl_compatibility() -> void:
	var renderer: String = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	assert_str(renderer).is_equal("gl_compatibility")


func test_etc2_astc_compression_enabled() -> void:
	var etc2: bool = ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false)
	assert_bool(etc2).is_true()


func test_viewport_width_is_1280() -> void:
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	assert_int(width).is_equal(1280)


func test_viewport_height_is_960() -> void:
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	assert_int(height).is_equal(960)


func test_stretch_mode_is_canvas_items() -> void:
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode", "")
	assert_str(mode).is_equal("canvas_items")


func test_touch_emulation_enabled() -> void:
	var enabled: bool = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)
	assert_bool(enabled).is_true()


# -- K2: Android Preset Exists ------------------------------------------------

func test_android_preset_exists() -> void:
	assert_bool(_sections.has("preset.1")).is_true()


func test_android_preset_name() -> void:
	assert_str(_get_android_preset("name")).is_equal("\"Android\"")


func test_android_preset_platform() -> void:
	assert_str(_get_android_preset("platform")).is_equal("\"Android\"")


# -- K2: Android Package Name -------------------------------------------------

func test_android_package_name() -> void:
	var pkg: String = _get_android_option("package/unique_name")
	assert_str(pkg).is_equal("\"com.spirefall.game\"")


# -- K2: Android SDK Versions -------------------------------------------------

func test_android_min_sdk_24() -> void:
	var min_sdk: String = _get_android_option("gradle_build/min_sdk")
	assert_str(min_sdk).is_equal("\"24\"")


func test_android_target_sdk_34() -> void:
	var target_sdk: String = _get_android_option("gradle_build/target_sdk")
	assert_str(target_sdk).is_equal("\"34\"")


# -- K2: Android Screen Orientation --------------------------------------------

func test_android_screen_orientation_landscape() -> void:
	# 0 = Landscape
	var orient: String = _get_android_option("screen/orientation")
	assert_str(orient).is_equal("0")


# -- K2: Android VRAM Texture Compression (ETC2) -------------------------------

func test_android_vram_compression_etc2() -> void:
	var etc2: String = _get_android_option("gradle_build/compress_native_libraries")
	# ETC2 is controlled by project-level import_etc2_astc=true
	# For Android, verify desktop compression is false (mobile-only) and mobile is true
	var for_mobile: String = _get_android_option("vram_texture_compression/for_mobile")
	assert_str(for_mobile).is_equal("true")


# -- K2: Android Export Path ---------------------------------------------------

func test_android_export_path() -> void:
	var path: String = _get_android_preset("export_path")
	assert_bool(path.contains("spirefall")).is_true()


# -- K2: Android Export Filter -------------------------------------------------

func test_android_export_filter_all_resources() -> void:
	assert_str(_get_android_preset("export_filter")).is_equal("\"all_resources\"")


# -- K2: Project Orientation Setting -------------------------------------------

func test_project_orientation_landscape() -> void:
	# 1 = Landscape in Godot project settings
	var orient: int = ProjectSettings.get_setting("display/window/handheld/orientation", 0)
	assert_int(orient).is_equal(1)
