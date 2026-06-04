class_name AgentToolRegistry
extends RefCounted

signal tool_execution_started(tool_name: String, params: Dictionary)
signal tool_execution_completed(tool_name: String, result: Dictionary)
signal tool_execution_failed(tool_name: String, error: String)
signal resource_requested(resource_uri: String, params: Dictionary)
signal resource_loaded(resource_uri: String, content: Dictionary)
signal log_message(level: String, message: String)

var _tools: Dictionary = {}
var _resources: Dictionary = {}
var _prompts: Dictionary = {}
var _tool_list_dirty: bool = false
var _classifier = null
var _state_manager = null
var _log_level: int = AgentTypes.LogLevel.INFO
var _security_level: int = AgentTypes.SecurityLevel.STRICT
var _scene_structure_cache: Dictionary = {}
var _cache_timestamp: Dictionary = {}
var _tool_log_path: String = "user://agent_tool_verification_log.json"

func initialize() -> void:
	get_classifier()
	get_state_manager()

func call_tool(tool_name: String, params: Dictionary = {}) -> Dictionary:
	_log_info("Tool call: " + tool_name)
	_log_debug("Tool arguments: " + JSON.stringify(params))

	if not _tools.has(tool_name):
		var missing_error: String = "Tool not found: " + tool_name
		_log_error(missing_error)
		tool_execution_failed.emit(tool_name, missing_error)
		return {"error": missing_error}

	var tool: AgentTypes.AgentTool = _tools[tool_name]
	if not tool.enabled:
		var disabled_error: String = "Tool is disabled: " + tool_name
		_log_error(disabled_error)
		tool_execution_failed.emit(tool_name, disabled_error)
		return {"error": disabled_error}

	if not tool.callable.is_valid():
		var callable_error: String = "Tool callable is invalid: " + tool_name
		_log_error(callable_error)
		tool_execution_failed.emit(tool_name, callable_error)
		return {"error": callable_error}

	tool_execution_started.emit(tool_name, params)

	var result: Variant = await tool.callable.call(params)
	var result_dict: Dictionary = {}
	if result is Dictionary:
		result_dict = result
	else:
		result_dict = {"result": result}

	if result_dict.has("error"):
		tool_execution_failed.emit(tool_name, str(result_dict["error"]))
	else:
		tool_execution_completed.emit(tool_name, result_dict)

	_append_tool_log(tool_name, result_dict)
	_log_info("Tool execution completed: " + tool_name)
	return result_dict

func list_tools(include_disabled: bool = false) -> Array[Dictionary]:
	var tools_list: Array[Dictionary] = []
	for tool_name in _tools:
		var tool: AgentTypes.AgentTool = _tools[tool_name]
		if tool and tool.is_valid() and (include_disabled or tool.enabled):
			tools_list.append(tool.to_dict())
	return tools_list

func register_tool(name: String, description: String, input_schema: Dictionary, callable: Callable, output_schema: Dictionary = {}, annotations: Dictionary = {}, category: String = "core", group: String = "") -> void:
	var tool: AgentTypes.AgentTool = AgentTypes.AgentTool.new()
	tool.name = name
	tool.description = description
	tool.input_schema = input_schema
	tool.output_schema = output_schema
	tool.annotations = annotations
	tool.callable = callable
	tool.category = category
	tool.group = group
	tool.enabled = category == "core"

	if not tool.is_valid():
		_log_error("Invalid tool definition: " + name)
		return

	_tools[name] = tool
	_log_info("Tool registered: " + name)

func unregister_tool(name: String) -> void:
	if _tools.has(name):
		_tools.erase(name)
		_tool_list_dirty = true
		_log_info("Tool unregistered: " + name)

func get_tool(name: String) -> AgentTypes.AgentTool:
	return _tools.get(name, null)

func get_all_tools() -> Dictionary:
	return _tools.duplicate()

func get_tools_count() -> int:
	return _tools.size()

func get_registered_tools() -> Array:
	return list_tools(true)

func has_tool(name: String) -> bool:
	return _tools.has(name)

func set_tool_enabled(tool_name: String, enabled: bool) -> void:
	if _tools.has(tool_name):
		_tools[tool_name].enabled = enabled
		_tool_list_dirty = true
		_log_info(("Tool enabled: " if enabled else "Tool disabled: ") + tool_name)
	elif enabled:
		_log_warn("Cannot enable unregistered tool: " + tool_name)

func set_group_enabled(group_name: String, enabled: bool) -> int:
	var classifier = get_classifier()
	var group_tools: Array[String] = classifier.get_group_tools(group_name)
	var changed_count: int = 0
	for tool_name in group_tools:
		if _tools.has(tool_name) and _tools[tool_name].enabled != enabled:
			_tools[tool_name].enabled = enabled
			changed_count += 1
	if changed_count > 0:
		_tool_list_dirty = true
		_log_info("Group '" + group_name + "' " + ("enabled" if enabled else "disabled") + ": " + str(changed_count) + " tools affected")
	return changed_count

func get_tool_list_dirty() -> bool:
	return _tool_list_dirty

func clear_tool_list_dirty() -> void:
	_tool_list_dirty = false

func notify_tool_list_changed() -> void:
	_tool_list_dirty = false

func get_classifier():
	if _classifier == null:
		_classifier = load("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd").new()
	return _classifier

func get_state_manager():
	if _state_manager == null:
		_state_manager = load("res://addons/godot_mcp/native_mcp/tool_state_manager.gd").new()
	return _state_manager

func load_tool_states() -> int:
	var saved_states: Dictionary = get_state_manager().load_state()
	if not saved_states.is_empty():
		get_state_manager().apply_states_to_registry(self, saved_states)
		_log_info("Loaded saved tool states: " + str(saved_states.size()) + " tools")
	return saved_states.size()

func save_tool_states() -> void:
	var states: Dictionary = get_state_manager().capture_states_from_registry(self)
	get_state_manager().save_state(states)

func register_resource(uri: String, name: String, mime_type: String, load_callable: Callable, description: String = "") -> void:
	var resource: AgentTypes.AgentResource = AgentTypes.AgentResource.new()
	resource.uri = uri
	resource.name = name
	resource.description = description
	resource.mime_type = mime_type
	resource.load_callable = load_callable

	if not resource.is_valid():
		_log_error("Invalid resource definition: " + uri)
		return

	_resources[uri] = resource
	_log_info("Resource registered: " + uri)

func unregister_resource(uri: String) -> void:
	if _resources.has(uri):
		_resources.erase(uri)
		_log_info("Resource unregistered: " + uri)

func get_resource(uri: String) -> AgentTypes.AgentResource:
	return _resources.get(uri, null)

func get_all_resources() -> Dictionary:
	return _resources.duplicate()

func list_resources() -> Array[Dictionary]:
	var resources_list: Array[Dictionary] = []
	for uri in _resources:
		var resource: AgentTypes.AgentResource = _resources[uri]
		if resource and resource.is_valid():
			resources_list.append(resource.to_dict())
	return resources_list

func read_resource(uri: String, params: Dictionary = {}) -> Dictionary:
	if not _resources.has(uri):
		return {"error": "Resource not found: " + uri}

	var resource: AgentTypes.AgentResource = _resources[uri]
	resource_requested.emit(uri, params)

	var content: Variant = await resource.load_callable.call(params)
	var content_dict: Dictionary = content if content is Dictionary else {"result": content}
	resource_loaded.emit(uri, content_dict)
	return content_dict

func get_resources_count() -> int:
	return _resources.size()

func register_prompt(name: String, description: String, arguments: Array[Dictionary], get_callable: Callable = Callable()) -> void:
	var prompt: AgentTypes.AgentPrompt = AgentTypes.AgentPrompt.new()
	prompt.name = name
	prompt.description = description
	prompt.arguments = arguments
	_prompts[name] = prompt
	_log_info("Prompt registered: " + name)

func get_cached_scene_structure(scene_path: String) -> Dictionary:
	var current_time: int = Time.get_unix_time_from_system()
	if _scene_structure_cache.has(scene_path):
		var cache_time: int = _cache_timestamp.get(scene_path, 0)
		if current_time - cache_time < 300:
			_log_debug("Cache hit: " + scene_path)
			return _scene_structure_cache[scene_path]
	_log_debug("Cache miss: " + scene_path)
	return {}

func set_cached_scene_structure(scene_path: String, structure: Dictionary) -> void:
	_scene_structure_cache[scene_path] = structure
	_cache_timestamp[scene_path] = Time.get_unix_time_from_system()
	_log_debug("Cache set: " + scene_path)

func clear_cache() -> void:
	_scene_structure_cache.clear()
	_cache_timestamp.clear()
	_log_info("Cache cleared")

func set_log_level(level: int) -> void:
	_log_level = level
	_log_info("Log level set to: " + str(level))

func set_security_level(level: int) -> void:
	_security_level = level
	_log_info("Security level set to: " + str(level))

func clear_tool_log() -> void:
	var file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.WRITE)
	if file:
		file.store_string("[]")
		file.close()

func cleanup() -> void:
	save_tool_states()

func _log_error(message: String) -> void:
	if _log_level >= AgentTypes.LogLevel.ERROR:
		call_deferred("emit_signal", "log_message", "ERROR", message)

func _log_warn(message: String) -> void:
	if _log_level >= AgentTypes.LogLevel.WARN:
		call_deferred("emit_signal", "log_message", "WARN", message)

func _log_info(message: String) -> void:
	if _log_level >= AgentTypes.LogLevel.INFO:
		call_deferred("emit_signal", "log_message", "INFO", message)

func _log_debug(message: String) -> void:
	if _log_level >= AgentTypes.LogLevel.DEBUG:
		call_deferred("emit_signal", "log_message", "DEBUG", message)

func _append_tool_log(tool_name: String, result: Dictionary) -> void:
	var log_entry: Dictionary = {
		"tool": tool_name,
		"timestamp": Time.get_unix_time_from_system(),
		"status": "error" if result.has("error") else "ok",
		"result_keys": result.keys()
	}

	var existing: Array = []
	if FileAccess.file_exists(_tool_log_path):
		var read_file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.READ)
		if read_file:
			var json: JSON = JSON.new()
			if json.parse(read_file.get_as_text()) == OK:
				var data: Variant = json.get_data()
				if data is Array:
					existing = data
			read_file.close()

	existing.append(log_entry)

	var write_file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(JSON.stringify(existing, "\t"))
		write_file.close()
