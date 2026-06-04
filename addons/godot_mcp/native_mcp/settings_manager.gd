class_name AgentSettingsManager
extends "res://addons/godot_mcp/native_mcp/config_manager.gd"

const CONFIG_FILE_NAME: String = "agent_settings.cfg"
const LEGACY_CONFIG_FILE_NAME: String = "mcp_settings.cfg"
const SECTION_SETTINGS: String = "settings"

const DEFAULT_SETTINGS: Dictionary = {
	"log_level": 2,
	"security_level": 1,
	"language": "en"
}

func _init() -> void:
	config_file_name = CONFIG_FILE_NAME
	config_section = SECTION_SETTINGS
	storage_version = 1

func load_settings() -> Dictionary:
	var saved: Dictionary = load_config()
	if saved.is_empty():
		var original_name: String = config_file_name
		config_file_name = LEGACY_CONFIG_FILE_NAME
		saved = load_config()
		config_file_name = original_name
	var merged: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	for key in saved:
		if merged.has(key):
			merged[key] = saved[key]
	return merged

func save_settings(settings: Dictionary) -> bool:
	config_file_name = CONFIG_FILE_NAME
	return save_config(settings)
