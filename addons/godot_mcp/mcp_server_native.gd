@tool
extends EditorPlugin

@export var vibe_coding_mode: bool = true:
	set(value):
		vibe_coding_mode = value
		notify_property_list_changed()

@export_range(0, 3, 1) var log_level: int = 2:
	set(value):
		log_level = value
		if _tool_registry:
			_tool_registry.set_log_level(value)
		notify_property_list_changed()

@export var security_level: int = 1:
	set(value):
		security_level = value
		if _tool_registry:
			_tool_registry.set_security_level(value)
		notify_property_list_changed()

var _tool_registry: RefCounted = null
var _main_panel: Control = null
var _editor_interface: EditorInterface = null
var _tool_instances: Dictionary = {}
var _debugger_bridge: MCPDebuggerBridge = null

const TOOL_SCRIPT_PATHS: Dictionary = {
	"NodeToolsNative": "res://addons/godot_mcp/tools/node_tools_native.gd",
	"ScriptToolsNative": "res://addons/godot_mcp/tools/script_tools_native.gd",
	"SceneToolsNative": "res://addons/godot_mcp/tools/scene_tools_native.gd",
	"EditorToolsNative": "res://addons/godot_mcp/tools/editor_tools_native.gd",
	"DebugToolsNative": "res://addons/godot_mcp/tools/debug_tools_native.gd",
	"ProjectToolsNative": "res://addons/godot_mcp/tools/project_tools_native.gd"
}

func _enter_tree() -> void:
	_editor_interface = get_editor_interface()
	if not _editor_interface:
		_log_error("Failed to get EditorInterface")
		return

	_tool_registry = _instantiate_script("res://addons/godot_mcp/native_mcp/mcp_server_core.gd")
	if not _tool_registry:
		_log_error("Failed to create agent tool registry")
		return

	_tool_registry.set_log_level(log_level)
	_tool_registry.set_security_level(security_level)
	_tool_registry.tool_execution_started.connect(_on_tool_started)
	_tool_registry.tool_execution_completed.connect(_on_tool_completed)
	_tool_registry.tool_execution_failed.connect(_on_tool_failed)
	_tool_registry.log_message.connect(_on_log_message)

	Engine.set_meta("GodotAgentToolsPlugin", self)
	Engine.set_meta("GodotMCPPlugin", self)

	_debugger_bridge = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()
	if not _debugger_bridge:
		_log_error("Failed to create debugger bridge instance")
		return
	add_debugger_plugin(_debugger_bridge)

	_register_all_tools()
	_ensure_runtime_probe_autoload()
	_register_all_resources()
	_tool_registry.load_tool_states()
	_create_main_screen_panel()
	_log_info("Godot agent tools plugin initialized")

func _exit_tree() -> void:
	if _tool_registry and _tool_registry.has_method("cleanup"):
		_tool_registry.cleanup()

	if _main_panel:
		EditorInterface.get_editor_main_screen().remove_child(_main_panel)
		_main_panel.queue_free()
		_main_panel = null

	_remove_runtime_probe_autoload()

	if _debugger_bridge:
		remove_debugger_plugin(_debugger_bridge)
		_debugger_bridge = null

	_tool_registry = null
	if Engine.has_meta("GodotAgentToolsPlugin"):
		Engine.remove_meta("GodotAgentToolsPlugin")
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _main_panel:
		_main_panel.visible = visible

func _get_plugin_name() -> String:
	return "Agent Tools"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/godot_mcp/icon.svg")

func get_tool_registry() -> RefCounted:
	return _tool_registry

func get_debugger_bridge() -> MCPDebuggerBridge:
	return _debugger_bridge

func _has_settings() -> bool:
	return true

func _get_property_list() -> Array:
	return [
		{
			"name": "Agent Tool Settings",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY
		},
		{
			"name": "vibe_coding_mode",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "log_level",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "ERROR,WARN,INFO,DEBUG",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "security_level",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "PERMISSIVE,STRICT",
			"usage": PROPERTY_USAGE_DEFAULT
		}
	]

func get_agent_status() -> Dictionary:
	if not _tool_registry:
		return {"status": "not_initialized"}

	return {
		"status": "ready",
		"log_level": log_level,
		"security_level": security_level,
		"tools_count": _tool_registry.get_tools_count(),
		"resources_count": _tool_registry.get_resources_count()
	}

func _register_all_tools() -> void:
	if not _tool_registry:
		_log_error("Agent tool registry is not available")
		return

	for module_name in TOOL_SCRIPT_PATHS.keys():
		var instance: Variant = _instantiate_script(str(TOOL_SCRIPT_PATHS[module_name]))
		if not instance:
			_log_error("Failed to instantiate tool module: " + str(module_name))
			continue
		_register_tool_module(str(module_name), instance)

	_log_info("All agent tools registered. Total: " + str(_tool_registry.get_tools_count()))

func _register_tool_module(module_name: String, instance: RefCounted) -> void:
	if not instance:
		return

	_tool_instances[module_name] = instance
	var tools_before: int = _tool_registry.get_tools_count() if _tool_registry and _tool_registry.has_method("get_tools_count") else -1

	if instance.has_method("initialize"):
		instance.initialize(_editor_interface)

	if instance.has_method("register_tools"):
		instance.register_tools(_tool_registry)

	var tools_after: int = _tool_registry.get_tools_count() if _tool_registry and _tool_registry.has_method("get_tools_count") else -1
	_log_info("Registered tool module: %s (added=%d)" % [module_name, tools_after - tools_before])

func _instantiate_script(script_path: String) -> Variant:
	var script: Script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not script:
		_log_error("Failed to load script: " + script_path)
		return null
	return script.new()

func _ensure_runtime_probe_autoload() -> void:
	var autoload_key: String = "autoload/MCPRuntimeProbe"
	var autoload_path: String = "*res://addons/godot_mcp/runtime/mcp_runtime_probe.gd"
	if not ProjectSettings.has_setting(autoload_key):
		ProjectSettings.set_setting(autoload_key, autoload_path)
		ProjectSettings.save()
		_log_info("Runtime probe autoload registered")

func _remove_runtime_probe_autoload() -> void:
	var autoload_key: String = "autoload/MCPRuntimeProbe"
	if ProjectSettings.has_setting(autoload_key):
		ProjectSettings.clear(autoload_key)
		ProjectSettings.save()
		_log_info("Runtime probe autoload removed")

func _register_all_resources() -> void:
	if not _tool_registry:
		_log_error("Agent tool registry is not available")
		return

	_register_scene_resources()
	_register_script_resources()
	_register_project_resources()
	_register_editor_resources()
	_log_info("All agent resources registered")

func _register_scene_resources() -> void:
	_tool_registry.register_resource("godot://scene/list", "Godot Scene List", "application/json", Callable(self, "_resource_scene_list"), "List of all scene files in the project")
	_tool_registry.register_resource("godot://scene/current", "Current Scene", "application/json", Callable(self, "_resource_scene_current"), "Structure of the currently open scene in the editor")

func _register_script_resources() -> void:
	_tool_registry.register_resource("godot://script/list", "Godot Script List", "application/json", Callable(self, "_resource_script_list"), "List of all GDScript files in the project")
	_tool_registry.register_resource("godot://script/current", "Current Script", "text/plain", Callable(self, "_resource_script_current"), "Content of the currently open script in the editor")

func _register_project_resources() -> void:
	_tool_registry.register_resource("godot://project/info", "Project Info", "application/json", Callable(self, "_resource_project_info"), "Project name, version, and basic information")
	_tool_registry.register_resource("godot://project/settings", "Project Settings", "application/json", Callable(self, "_resource_project_settings"), "Project setting values and configuration")

func _register_editor_resources() -> void:
	_tool_registry.register_resource("godot://editor/state", "Editor State", "application/json", Callable(self, "_resource_editor_state"), "Current editor state and active tools")

func _resource_scene_list(params: Dictionary) -> Dictionary:
	var scenes: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if not dir:
		return {"contents": [{"uri": "godot://scene/list", "mimeType": "application/json", "text": "[]"}]}

	_find_files_recursive(dir, ".tscn", scenes)
	return {
		"contents": [{
			"uri": "godot://scene/list",
			"mimeType": "application/json",
			"text": JSON.stringify({"scenes": scenes, "count": scenes.size(), "timestamp": Time.get_unix_time_from_system()}, "\t", true)
		}]
	}

func _resource_scene_current(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://scene/current", "mimeType": "application/json", "text": "{}"}]}

	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if not scene_root:
		return {"contents": [{"uri": "godot://scene/current", "mimeType": "application/json", "text": "{}"}]}

	var scene_info: Dictionary = {
		"name": scene_root.name,
		"path": scene_root.scene_file_path,
		"type": scene_root.get_class(),
		"node_count": _count_nodes(scene_root),
		"children": _get_node_tree(scene_root, 2)
	}
	return {"contents": [{"uri": "godot://scene/current", "mimeType": "application/json", "text": JSON.stringify(scene_info, "\t", true)}]}

func _resource_script_list(params: Dictionary) -> Dictionary:
	var scripts: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if not dir:
		return {"contents": [{"uri": "godot://script/list", "mimeType": "application/json", "text": "[]"}]}

	_find_files_recursive(dir, ".gd", scripts)
	return {
		"contents": [{
			"uri": "godot://script/list",
			"mimeType": "application/json",
			"text": JSON.stringify({"scripts": scripts, "count": scripts.size(), "timestamp": Time.get_unix_time_from_system()}, "\t", true)
		}]
	}

func _resource_script_current(params: Dictionary) -> Dictionary:
	return {
		"contents": [{
			"uri": "godot://script/current",
			"mimeType": "text/plain",
			"text": "# Current script access is not implemented yet."
		}]
	}

func _resource_project_info(params: Dictionary) -> Dictionary:
	var project_info: Dictionary = {
		"name": ProjectSettings.get_setting("application/config/name", "Untitled Project"),
		"version": ProjectSettings.get_setting("application/config/version", "1.0"),
		"description": ProjectSettings.get_setting("application/config/description", ""),
		"author": ProjectSettings.get_setting("application/config/author", ""),
		"godot_version": _get_godot_version(),
		"timestamp": Time.get_unix_time_from_system()
	}
	return {"contents": [{"uri": "godot://project/info", "mimeType": "application/json", "text": JSON.stringify(project_info, "\t", true)}]}

func _resource_project_settings(params: Dictionary) -> Dictionary:
	var settings: Dictionary = {}
	for property in ProjectSettings.get_property_list():
		var property_name: String = property.get("name", "")
		if property_name.begins_with("application/") or property_name.begins_with("display/") or property_name.begins_with("rendering/"):
			settings[property_name] = ProjectSettings.get_setting(property_name)
	return {"contents": [{"uri": "godot://project/settings", "mimeType": "application/json", "text": JSON.stringify({"settings": settings, "count": settings.size(), "timestamp": Time.get_unix_time_from_system()}, "\t", true)}]}

func _resource_editor_state(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://editor/state", "mimeType": "application/json", "text": "{}"}]}

	var editor_state: Dictionary = {
		"current_scene": "",
		"selected_nodes": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if scene_root:
		editor_state["current_scene"] = scene_root.scene_file_path

	var selection = _editor_interface.get_selection()
	if selection:
		for node in selection.get_selected_nodes():
			editor_state["selected_nodes"].append(str(node.get_path()))

	return {"contents": [{"uri": "godot://editor/state", "mimeType": "application/json", "text": JSON.stringify(editor_state, "\t", true)}]}

static func _find_files_recursive(dir: DirAccess, extension: String, result: Array, base_path: String = "res://") -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = base_path.path_join(file_name)
		if dir.current_is_dir():
			var sub_dir: DirAccess = DirAccess.open(full_path + "/")
			if sub_dir:
				_find_files_recursive(sub_dir, extension, result, full_path + "/")
		elif file_name.ends_with(extension):
			result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

static func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

static func _get_node_tree(node: Node, max_depth: int, current_depth: int = 0) -> Array:
	if current_depth >= max_depth:
		return []

	var result: Array = []
	for child in node.get_children():
		result.append({
			"name": child.name,
			"type": child.get_class(),
			"children": _get_node_tree(child, max_depth, current_depth + 1)
		})
	return result

static func _get_godot_version() -> Dictionary:
	var info: Dictionary = Engine.get_version_info()
	return {
		"version": info["string"],
		"major": info["major"],
		"minor": info["minor"],
		"patch": info["patch"]
	}

func _create_main_screen_panel() -> void:
	var panel_scene: PackedScene = load("res://addons/godot_mcp/ui/mcp_panel_native.tscn")
	if not panel_scene:
		_log_error("Failed to load agent tools panel scene")
		return

	_main_panel = panel_scene.instantiate()
	if not _main_panel:
		_log_error("Failed to instantiate agent tools panel")
		return

	EditorInterface.get_editor_main_screen().add_child(_main_panel)
	_make_visible(false)

	if _main_panel.has_method("set_plugin"):
		_main_panel.set_plugin(self)

	if _main_panel.has_method("set_tool_registry"):
		_main_panel.set_tool_registry(_tool_registry)

	_log_info("Agent tools panel created")

func _on_tool_started(tool_name: String, params: Dictionary) -> void:
	_log_info("Tool started: " + tool_name)

func _on_tool_completed(tool_name: String, result: Dictionary) -> void:
	_log_info("Tool completed: " + tool_name)

func _on_tool_failed(tool_name: String, error: String) -> void:
	_log_error("Tool failed: " + tool_name + " - " + error)

func _on_log_message(level: String, message: String) -> void:
	if _main_panel and _main_panel.has_method("update_log"):
		_main_panel.update_log("[" + level + "] " + message)

func _log_error(message: String) -> void:
	if _tool_registry:
		_tool_registry._log_error(message)
	else:
		push_error(message)

func _log_warn(message: String) -> void:
	if _tool_registry:
		_tool_registry._log_warn(message)
	else:
		push_warning(message)

func _log_info(message: String) -> void:
	if _tool_registry:
		_tool_registry._log_info(message)

func _log_debug(message: String) -> void:
	if _tool_registry:
		_tool_registry._log_debug(message)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_tool_registry = null
