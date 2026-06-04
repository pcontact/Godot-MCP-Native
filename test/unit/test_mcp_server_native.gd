extends "res://addons/gut/test.gd"

var _plugin_script: GDScript = null

func before_each():
	_plugin_script = load("res://addons/godot_mcp/mcp_server_native.gd")

func after_each():
	_plugin_script = null

func test_plugin_script_loads():
	assert_ne(_plugin_script, null, "Plugin script should load successfully")

func test_plugin_has_enter_tree():
	assert_true(_plugin_script.has_method("_enter_tree") or _plugin_script.get_script_method_list().any(func(m): return m.name == "_enter_tree"), "Should have _enter_tree method")

func test_plugin_has_exit_tree():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_exit_tree"), "Should have _exit_tree method")

func test_plugin_does_not_have_start_server():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_false(method_names.has("start_server"), "Server start API should be removed")

func test_plugin_does_not_have_stop_server():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_false(method_names.has("stop_server"), "Server stop API should be removed")

func test_plugin_has_get_agent_status():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("get_agent_status"), "Should have get_agent_status method")
	assert_true(method_names.has("get_tool_registry"), "Should expose direct tool registry")

func test_find_files_recursive():
	var result: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if dir:
		_plugin_script._find_files_recursive(dir, ".tscn", result)
		assert_true(result.size() > 0, "Should find at least one .tscn file in the project")

func test_find_files_recursive_gd():
	var result: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if dir:
		_plugin_script._find_files_recursive(dir, ".gd", result)
		assert_true(result.size() > 0, "Should find at least one .gd file in the project")

func test_count_nodes():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)
	var count: int = _plugin_script._count_nodes(root)
	assert_eq(count, 2, "Should count root + 1 child")

func test_get_node_tree():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child1"
	root.add_child(child)
	var tree: Array = _plugin_script._get_node_tree(root, 1)
	assert_eq(tree.size(), 1, "Should have 1 child")
	assert_eq(tree[0]["name"], "Child1", "Child name should match")

func test_get_godot_version():
	var version: Dictionary = _plugin_script._get_godot_version()
	assert_true(version.has("version"), "Should have version key")
	assert_true(version.has("major"), "Should have major key")
	assert_true(version["major"] >= 4, "Godot major should be >= 4")

func test_plugin_name():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_get_plugin_name"), "Should have _get_plugin_name method")
	assert_true(method_names.has("_has_main_screen"), "Should have _has_main_screen method for main screen plugin")
	assert_true(method_names.has("_make_visible"), "Should have _make_visible method for main screen plugin")
	assert_true(method_names.has("_get_plugin_icon"), "Should have _get_plugin_icon method for main screen plugin")
	assert_true(method_names.has("_create_main_screen_panel"), "Should have _create_main_screen_panel method")

func test_export_variables():
	var script_props: Array = _plugin_script.get_script_property_list()
	var prop_names: Array = script_props.map(func(p): return p["name"])
	assert_false(prop_names.has("auto_start"), "Should not have auto_start export")
	assert_false(prop_names.has("transport_mode"), "Should not have transport_mode export")
	assert_false(prop_names.has("http_port"), "Should not have http_port export")
	assert_false(prop_names.has("auth_enabled"), "Should not have auth_enabled export")
	assert_true(prop_names.has("log_level"), "Should have log_level export")
	assert_true(prop_names.has("vibe_coding_mode"), "Should have vibe_coding_mode export")

func test_has_load_tool_states_in_enter_tree():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_enter_tree"), "Should have _enter_tree method")
	var source_code: String = _plugin_script.source_code
	assert_true(source_code.contains("load_tool_states"), "_enter_tree should call load_tool_states")
	assert_true(source_code.contains("_create_main_screen_panel"), "Should still create main screen panel")
	var load_pos: int = source_code.find("load_tool_states")
	var panel_pos: int = source_code.find("_create_main_screen_panel")
	assert_true(load_pos >= 0, "load_tool_states should exist in source")
	assert_true(panel_pos >= 0, "_create_main_screen_panel should exist in source")
	assert_true(load_pos < panel_pos, "load_tool_states should be called BEFORE _create_main_screen_panel")

func test_has_autoload_registration_methods():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_ensure_runtime_probe_autoload"), "Should have _ensure_runtime_probe_autoload method")
	assert_true(method_names.has("_remove_runtime_probe_autoload"), "Should have _remove_runtime_probe_autoload method")

func test_autoload_registered_in_enter_tree():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_enter_tree"), "Should have _enter_tree method")
	var source_code: String = _plugin_script.source_code
	assert_true(source_code.contains("_ensure_runtime_probe_autoload"), "_enter_tree should call _ensure_runtime_probe_autoload")
	var register_pos: int = source_code.find("_register_all_tools")
	var autoload_pos: int = source_code.find("_ensure_runtime_probe_autoload")
	var panel_pos: int = source_code.find("_create_main_screen_panel")
	assert_true(register_pos >= 0, "_register_all_tools should exist in source")
	assert_true(autoload_pos >= 0, "_ensure_runtime_probe_autoload should exist in source")
	assert_true(panel_pos >= 0, "_create_main_screen_panel should exist in source")
	assert_true(register_pos < autoload_pos, "_ensure_runtime_probe_autoload should be called AFTER _register_all_tools")
	assert_true(autoload_pos < panel_pos, "_ensure_runtime_probe_autoload should be called BEFORE _create_main_screen_panel")

func test_autoload_removed_in_exit_tree():
	var source_code: String = _plugin_script.source_code
	assert_true(source_code.contains("_remove_runtime_probe_autoload"), "_exit_tree should call _remove_runtime_probe_autoload")
