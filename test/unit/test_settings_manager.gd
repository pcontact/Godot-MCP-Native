extends "res://addons/gut/test.gd"

var _sm = null

func before_each():
	_sm = load("res://addons/godot_mcp/native_mcp/settings_manager.gd").new()
	_remove_storage_file("agent_settings.cfg")
	_remove_storage_file("mcp_settings.cfg")

func after_each():
	if _sm:
		_remove_storage_file("agent_settings.cfg")
		_remove_storage_file("mcp_settings.cfg")
	_sm = null

func _remove_storage_file(file_name: String) -> void:
	var original_name: String = _sm.config_file_name
	_sm.config_file_name = file_name
	var path: String = _sm.get_storage_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_sm.config_file_name = original_name

func test_settings_manager_initializes():
	assert_ne(_sm, null, "Settings manager should initialize")

func test_default_settings_are_agent_only():
	var defaults: Dictionary = _sm.DEFAULT_SETTINGS
	assert_eq(defaults.keys().size(), 3, "Defaults should only include internal agent settings")
	assert_eq(defaults["log_level"], 2, "Default log_level should be 2")
	assert_eq(defaults["security_level"], 1, "Default security_level should be 1")
	assert_eq(defaults["language"], "en", "Default language should be 'en'")

func test_load_settings_returns_defaults():
	var settings: Dictionary = _sm.load_settings()
	assert_eq(settings["log_level"], 2, "Default log_level should be 2")
	assert_eq(settings["security_level"], 1, "Default security_level should be 1")
	assert_eq(settings["language"], "en", "Default language should be 'en'")
	assert_false(settings.has("transport_mode"), "Transport settings should not be present")

func test_save_and_load_settings():
	var saved: bool = _sm.save_settings({
		"log_level": 3,
		"security_level": 0,
		"language": "zh"
	})
	assert_true(saved, "Save should succeed")

	var loaded: Dictionary = _sm.load_settings()
	assert_eq(loaded["log_level"], 3, "log_level should be saved")
	assert_eq(loaded["security_level"], 0, "security_level should be saved")
	assert_eq(loaded["language"], "zh", "language should be saved")

func test_load_settings_ignores_legacy_transport_keys():
	_sm.save_settings({
		"transport_mode": "http",
		"http_port": 9080,
		"auth_enabled": true,
		"log_level": 1
	})
	var loaded: Dictionary = _sm.load_settings()
	assert_eq(loaded["log_level"], 1, "Known setting should be preserved")
	assert_false(loaded.has("transport_mode"), "Legacy transport_mode should be ignored")
	assert_false(loaded.has("http_port"), "Legacy http_port should be ignored")
	assert_false(loaded.has("auth_enabled"), "Legacy auth_enabled should be ignored")

func test_default_settings_not_modified_by_load():
	var orig_defaults: Dictionary = _sm.DEFAULT_SETTINGS.duplicate(true)
	var loaded: Dictionary = _sm.load_settings()
	assert_eq(_sm.DEFAULT_SETTINGS, orig_defaults, "DEFAULT_SETTINGS should not be mutated")

func test_config_file_name_is_agent_settings():
	assert_eq(_sm.config_file_name, "agent_settings.cfg", "Config file name should be agent_settings.cfg")

func test_config_section_is_settings():
	assert_eq(_sm.config_section, "settings", "Config section should be 'settings'")
