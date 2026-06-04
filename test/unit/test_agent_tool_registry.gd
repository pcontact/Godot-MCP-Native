extends "res://addons/gut/test.gd"

var _registry: RefCounted = null

func before_each():
	_registry = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

func after_each():
	_registry = null

func test_register_tool():
	_registry.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	assert_true(_registry.has_tool("test_tool"), "Should have registered tool")

func test_register_tool_with_category_and_group():
	_registry.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"}, {}, {}, "supplementary", "Editor-Advanced")
	var tool = _registry.get_tool("test_tool")
	assert_eq(tool.category, "supplementary", "Tool category should be supplementary")
	assert_eq(tool.group, "Editor-Advanced", "Tool group should be Editor-Advanced")
	assert_false(tool.enabled, "Supplementary tools should be disabled by default")

func test_list_tools_excludes_disabled_by_default():
	_registry.register_tool("core_tool", "Core", {"type": "object"}, func(args): return {})
	_registry.register_tool("supp_tool", "Supp", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	var enabled_tools: Array = _registry.list_tools()
	assert_eq(enabled_tools.size(), 1, "Only enabled tools should be listed by default")
	assert_eq(enabled_tools[0]["name"], "core_tool", "Core tool should be listed")

func test_list_tools_can_include_disabled():
	_registry.register_tool("supp_tool", "Supp", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	var tools: Array = _registry.list_tools(true)
	assert_eq(tools.size(), 1, "Disabled tool should be included")
	assert_false(tools[0]["enabled"], "Disabled state should be present in metadata")

func test_unregister_tool():
	_registry.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_registry.unregister_tool("test_tool")
	assert_false(_registry.has_tool("test_tool"), "Should not have unregistered tool")

func test_set_tool_enabled():
	_registry.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_registry.set_tool_enabled("test_tool", false)
	assert_false(_registry.get_tool("test_tool").enabled, "Tool should be disabled")
	_registry.set_tool_enabled("test_tool", true)
	assert_true(_registry.get_tool("test_tool").enabled, "Tool should be re-enabled")

func test_set_tool_enabled_sets_dirty_flag():
	_registry.register_tool("test_tool", "Test", {"type": "object"}, func(args): return {})
	assert_false(_registry.get_tool_list_dirty(), "Dirty flag should be false initially")
	_registry.set_tool_enabled("test_tool", false)
	assert_true(_registry.get_tool_list_dirty(), "Dirty flag should be true after disabling tool")

func test_clear_tool_list_dirty():
	_registry.register_tool("test_tool", "Test", {"type": "object"}, func(args): return {})
	_registry.set_tool_enabled("test_tool", false)
	_registry.clear_tool_list_dirty()
	assert_false(_registry.get_tool_list_dirty(), "Dirty flag should be false after clear")

func test_set_group_enabled_disables_group():
	_registry.register_tool("reload_project", "Reload", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	_registry.register_tool("execute_editor_script", "Exec Editor Script", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	_registry.set_group_enabled("Editor-Advanced", true)
	var changed: int = _registry.set_group_enabled("Editor-Advanced", false)
	assert_true(changed >= 2, "Should change at least 2 tools")
	assert_false(_registry.get_tool("reload_project").enabled, "Tool should be disabled")
	assert_false(_registry.get_tool("execute_editor_script").enabled, "Tool should be disabled")

func test_set_group_enabled_unknown_group():
	var changed: int = _registry.set_group_enabled("NonExistent", false)
	assert_eq(changed, 0, "Unknown group should change 0 tools")

func test_get_classifier():
	var classifier = _registry.get_classifier()
	assert_ne(classifier, null, "Should return a classifier instance")
	assert_true(classifier.has_method("get_all_tools"), "Classifier should have get_all_tools method")

func test_get_state_manager():
	var manager = _registry.get_state_manager()
	assert_ne(manager, null, "Should return a state manager instance")
	assert_true(manager.has_method("load_state"), "State manager should have load_state method")

func test_get_tools_count():
	assert_eq(_registry.get_tools_count(), 0, "Should have 0 tools initially")
	_registry.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {})
	assert_eq(_registry.get_tools_count(), 1, "Should have 1 tool after registration")

func test_register_resource():
	_registry.register_resource("godot://test", "Test", "application/json", func(params): return {})
	assert_eq(_registry.get_resources_count(), 1, "Should have 1 resource after registration")

func test_read_resource():
	_registry.register_resource("godot://test", "Test", "application/json", func(params): return {"value": 42})
	var result: Dictionary = await _registry.read_resource("godot://test")
	assert_eq(result["value"], 42, "Should return raw resource result")

func test_read_missing_resource_returns_error():
	var result: Dictionary = await _registry.read_resource("godot://missing")
	assert_eq(result["error"], "Resource not found: godot://missing", "Should return direct error")

func test_clear_cache():
	_registry.set_cached_scene_structure("res://test.tscn", {"test": true})
	_registry.clear_cache()
	assert_eq(_registry.get_cached_scene_structure("res://test.tscn").size(), 0, "Cache should be empty after clear")

func test_set_log_level():
	_registry.set_log_level(AgentTypes.LogLevel.DEBUG)
	assert_eq(_registry._log_level, AgentTypes.LogLevel.DEBUG, "Log level should be DEBUG")

func test_set_security_level():
	_registry.set_security_level(AgentTypes.SecurityLevel.STRICT)
	assert_eq(_registry._security_level, AgentTypes.SecurityLevel.STRICT, "Security level should be STRICT")

func test_sync_tool_call_returns_raw_dictionary():
	_registry.register_tool("sync_tool", "A sync tool", {"type": "object"}, func(args): return {"status": "ok"})
	var response: Dictionary = await _registry.call_tool("sync_tool", {})
	assert_eq(response, {"status": "ok"}, "Direct call should return raw tool dictionary")

func test_async_tool_call_returns_raw_dictionary():
	var tool_called: bool = false
	_registry.register_tool("async_tool", "An async tool", {"type": "object"}, func(args):
		tool_called = true
		await get_tree().process_frame
		return {"status": "async_ok"}
	)
	var response: Dictionary = await _registry.call_tool("async_tool", {})
	assert_true(tool_called, "Async tool should have been called")
	assert_eq(response, {"status": "async_ok"}, "Async direct call should return raw result")

func test_disabled_tool_call_returns_direct_error():
	_registry.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_registry.set_tool_enabled("test_tool", false)
	var response: Dictionary = await _registry.call_tool("test_tool", {})
	assert_eq(response["error"], "Tool is disabled: test_tool", "Calling disabled tool should return direct error")

func test_missing_tool_call_returns_direct_error():
	var response: Dictionary = await _registry.call_tool("missing_tool", {})
	assert_eq(response["error"], "Tool not found: missing_tool", "Calling missing tool should return direct error")
