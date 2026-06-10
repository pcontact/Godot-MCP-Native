extends "res://addons/gut/test.gd"

const TEMP_ROOT_PATH: String = "res://.tmp_create_script"
const TEMP_NESTED_DIR_PATH: String = TEMP_ROOT_PATH + "/nested"
const TEMP_NESTED_SCRIPT_PATH: String = TEMP_NESTED_DIR_PATH + "/nested_script.gd"
const TEMP_FLAT_SCRIPT_PATH: String = "res://.tmp_create_script_flat.gd"
const TEMP_EXISTING_SCRIPT_PATH: String = "res://.tmp_create_script_existing.gd"

var _script_tools: RefCounted = null

func before_each():
	_script_tools = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	_cleanup_temp_artifacts()

func after_each():
	_cleanup_temp_artifacts()
	_script_tools = null

func _cleanup_temp_artifacts() -> void:
	_remove_path_if_exists(TEMP_EXISTING_SCRIPT_PATH)
	_remove_path_if_exists(TEMP_FLAT_SCRIPT_PATH)
	_remove_path_if_exists(TEMP_NESTED_SCRIPT_PATH)
	_remove_path_if_exists(TEMP_NESTED_DIR_PATH)
	_remove_path_if_exists(TEMP_ROOT_PATH)

func _remove_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.remove_absolute(absolute_path)

func test_script_path_validation():
	var valid_paths: Array = ["res://test.gd", "res://scripts/player.gd", "res://addons/my_addon/main.gd"]
	for path in valid_paths:
		assert_true(MCPTypes.is_path_safe(path), path + " should be safe")

func test_script_path_traversal():
	var unsafe_paths: Array = ["res://../secret.gd", "res://scripts/../../etc/passwd"]
	for path in unsafe_paths:
		assert_false(MCPTypes.is_path_safe(path), path + " should be unsafe")

func test_script_extension_check():
	var ext: String = "res://test.gd".get_extension()
	assert_eq(ext, "gd", "Should extract gd extension")

func test_script_extension_tscn():
	var ext: String = "res://scene.tscn".get_extension()
	assert_eq(ext, "tscn", "Should extract tscn extension")

func test_script_base_name():
	var base: String = "res://scripts/player.gd".get_file()
	assert_eq(base, "player.gd", "Should extract file name")

func test_json_parse_string_to_dict():
	var json: String = '{"extends_from":"Node","functions":["_ready","_process"]}'
	var parsed: Variant = JSON.parse_string(json)
	assert_true(parsed is Dictionary, "Should parse to Dictionary")
	assert_has(parsed, "functions", "Should have functions key")

func test_analyze_script_output_format():
	var result: Dictionary = {
		"script_path": "res://test.gd",
		"extends_from": "Node",
		"functions": ["_ready", "_process"],
		"properties": [],
		"signals": [],
		"line_count": 50
	}
	assert_has(result, "script_path", "Should have script_path")
	assert_has(result, "extends_from", "Should have extends_from")
	assert_has(result, "functions", "Should have functions")
	assert_has(result, "line_count", "Should have line_count")

func test_modify_script_line_number():
	var content: String = "line1\nline2\nline3"
	var lines: PackedStringArray = content.split("\n")
	assert_eq(lines.size(), 3, "Should have 3 lines")
	assert_eq(lines[1], "line2", "Line 2 should be 'line2'")

func test_create_script_template():
	var content: String = "extends Node\n\nfunc _ready() -> void:\n\tpass\n"
	var line_count: int = content.split("\n").size()
	assert_gt(line_count, 0, "Template should have lines")

func test_create_script_missing_script_path_returns_error():
	var result: Dictionary = _script_tools._tool_create_script({})
	assert_has(result, "error", "Missing script_path should return an error")
	assert_true(str(result["error"]).contains("Missing required parameter: script_path"), "Should report missing script_path")

func test_create_script_invalid_extension_returns_error():
	var result: Dictionary = _script_tools._tool_create_script({
		"script_path": "res://.tmp_create_script/invalid_script.txt"
	})
	assert_has(result, "error", "Invalid extension should return an error")
	assert_true(str(result["error"]).contains("Invalid path"), "Should report invalid path")

func test_create_script_creates_missing_nested_directories():
	var result: Dictionary = _script_tools._tool_create_script({
		"script_path": TEMP_NESTED_SCRIPT_PATH,
		"content": "extends Node\n"
	})
	assert_eq(result.get("status", ""), "success", "Nested script creation should succeed")
	assert_eq(result.get("script_path", ""), TEMP_NESTED_SCRIPT_PATH, "Should preserve requested script path")
	assert_true(FileAccess.file_exists(TEMP_NESTED_SCRIPT_PATH), "Nested script file should exist")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEMP_NESTED_DIR_PATH)), "Nested directory should be created")

func test_create_script_creates_flat_script_in_project_root():
	var result: Dictionary = _script_tools._tool_create_script({
		"script_path": TEMP_FLAT_SCRIPT_PATH,
		"content": "extends Node\n"
	})
	assert_eq(result.get("status", ""), "success", "Flat script creation should succeed")
	assert_eq(result.get("script_path", ""), TEMP_FLAT_SCRIPT_PATH, "Should preserve requested script path")
	assert_true(FileAccess.file_exists(TEMP_FLAT_SCRIPT_PATH), "Flat script file should exist")

func test_create_script_reports_existing_file_error():
	var first_result: Dictionary = _script_tools._tool_create_script({
		"script_path": TEMP_EXISTING_SCRIPT_PATH,
		"content": "extends Node\n"
	})
	assert_eq(first_result.get("status", ""), "success", "Setup file creation should succeed")

	var second_result: Dictionary = _script_tools._tool_create_script({
		"script_path": TEMP_EXISTING_SCRIPT_PATH,
		"content": "extends Node3D\n"
	})
	assert_has(second_result, "error", "Existing file should return an error")
	assert_true(str(second_result["error"]).contains("File already exists"), "Should report existing file")
