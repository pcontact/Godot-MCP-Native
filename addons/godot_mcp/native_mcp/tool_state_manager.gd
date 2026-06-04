class_name AgentToolStateManager
extends "res://addons/godot_mcp/native_mcp/config_manager.gd"

const CONFIG_FILE_NAME: String = "agent_tool_state.cfg"
const LEGACY_CONFIG_FILE_NAME: String = "mcp_tool_state.cfg"
const SECTION_TOOLS: String = "tools"

var _classifier = null

func _init() -> void:
	config_file_name = CONFIG_FILE_NAME
	config_section = SECTION_TOOLS
	storage_version = 1
	_classifier = load("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd").new()

func load_state() -> Dictionary:
	var state: Dictionary = load_config()
	if not state.is_empty():
		return state

	var original_name: String = config_file_name
	config_file_name = LEGACY_CONFIG_FILE_NAME
	var legacy_state: Dictionary = load_config()
	config_file_name = original_name
	return legacy_state

func save_state(enabled_states: Dictionary) -> bool:
	config_file_name = CONFIG_FILE_NAME
	return save_config(enabled_states)

func apply_states_to_registry(registry: AgentToolRegistry, states: Dictionary) -> void:
	for tool_name in states:
		if registry.has_tool(tool_name):
			registry.set_tool_enabled(tool_name, bool(states[tool_name]))

func capture_states_from_registry(registry: AgentToolRegistry) -> Dictionary:
	var states: Dictionary = {}
	var tools: Array = registry.get_registered_tools()
	for tool_info in tools:
		states[tool_info["name"]] = tool_info["enabled"]
	return states

func apply_states_to_server(registry: AgentToolRegistry, states: Dictionary) -> void:
	apply_states_to_registry(registry, states)

func capture_states_from_server(registry: AgentToolRegistry) -> Dictionary:
	return capture_states_from_registry(registry)

func validate_core_tool_limit(states: Dictionary) -> Dictionary:
	var core_tools: Array[String] = _classifier.get_core_tools()
	var enabled_core_count: int = 0
	var core_limit: int = _classifier.get_core_max_count()

	for tool_name in core_tools:
		if bool(states.get(tool_name, true)):
			enabled_core_count += 1

	return {
		"over_limit": enabled_core_count > core_limit,
		"enabled_core_count": enabled_core_count,
		"core_limit": core_limit,
		"message": "Core tools enabled: %d/%d" % [enabled_core_count, core_limit]
	}
