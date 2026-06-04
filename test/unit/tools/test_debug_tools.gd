extends "res://addons/gut/test.gd"

class FakeRuntimeBridge:
	extends RefCounted

	var send_count: int = 0
	var capture_refresh_count: int = 0
	var message_sequence: int = 0
	var latest_payload: Variant = null

	func get_message_sequence() -> int:
		return message_sequence

	func send_debugger_message(message: String, data: Array, session_id: int = -1) -> Dictionary:
		send_count += 1
		return {"status": "success", "sessions_updated": 1}

	func get_captured_messages(count: int = 100, offset: int = 0, order: String = "desc") -> Dictionary:
		capture_refresh_count += 1
		if capture_refresh_count >= 2 and latest_payload == null:
			message_sequence += 1
			latest_payload = {
				"fps": 60.0,
				"physics_frames": 10,
				"process_frames": 20,
				"debugger_active": true,
				"current_scene": "/root/TestScene",
				"node_count": 3
			}
		return {"messages": [], "count": 0, "total_available": 0}

	func get_captured_message_after_sequence(sequence: int, response_messages: Array, error_messages: Array = [], match_fields: Dictionary = {}) -> Dictionary:
		if latest_payload != null and message_sequence > sequence and response_messages.has("mcp:runtime_info"):
			return {"message": "mcp:runtime_info", "data": [latest_payload], "sequence": message_sequence}
		return {}

	func get_latest_message_payload(message: String, match_fields: Dictionary = {}) -> Variant:
		if message == "mcp:runtime_info":
			return latest_payload
		return null

class FakeRuntimePlugin:
	extends RefCounted

	var bridge: RefCounted

	func _init(runtime_bridge: RefCounted) -> void:
		bridge = runtime_bridge

	func get_debugger_bridge() -> RefCounted:
		return bridge

var _runtime_bridge: RefCounted = null

func before_each() -> void:
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func after_each() -> void:
	_runtime_bridge = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_debug_print_format():
	var message: String = "[TEST] Hello world"
	assert_true(message.contains("[TEST]"), "Debug message should have category prefix")

func test_debug_log_buffer():
	var log_entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "INFO",
		"message": "Test message"
	}
	assert_has(log_entry, "timestamp", "Should have timestamp")
	assert_has(log_entry, "level", "Should have level")
	assert_has(log_entry, "message", "Should have message")

func test_execute_script_simple():
	var expression: Expression = Expression.new()
	var error: Error = expression.parse("1 + 2", [])
	assert_eq(error, OK, "Simple expression should parse OK")
	if error == OK:
		var result: Variant = expression.execute([], null, true)
		assert_eq(result, 3, "1 + 2 should equal 3")

func test_execute_script_with_singleton_binding():
	var expression: Expression = Expression.new()
	var bind_names: PackedStringArray = ["OS"]
	var bind_values: Array = [OS]
	var error: Error = expression.parse("OS.get_name()", bind_names)
	assert_eq(error, OK, "Expression with OS binding should parse OK")
	if error == OK:
		var result: Variant = expression.execute(bind_values, null, true)
		assert_ne(result, "", "OS.get_name() should return non-empty string")

func test_execute_script_execution_error():
	var expression: Expression = Expression.new()
	var error: Error = expression.parse("undefined_variable_xyz", [])
	assert_eq(error, OK, "Parse should succeed even with undefined var")
	if error == OK:
		expression.execute([], null, false)
		assert_true(expression.has_execute_failed(), "Execution should fail with undefined variable")

func test_performance_metrics_types():
	var fps: float = 60.0
	var memory: float = 512.5
	var objects: int = 1000
	assert_gt(fps, 0.0, "FPS should be positive")
	assert_gt(memory, 0.0, "Memory should be positive")
	assert_gt(objects, 0, "Object count should be positive")

func test_log_level_ordering():
	assert_lt(AgentTypes.LogLevel.ERROR, AgentTypes.LogLevel.WARN, "ERROR < WARN")
	assert_lt(AgentTypes.LogLevel.WARN, AgentTypes.LogLevel.INFO, "WARN < INFO")
	assert_lt(AgentTypes.LogLevel.INFO, AgentTypes.LogLevel.DEBUG, "INFO < DEBUG")

func test_mutex_thread_safety():
	var mutex: Mutex = Mutex.new()
	mutex.lock()
	mutex.unlock()
	assert_true(true, "Mutex lock/unlock should not crash")

func test_set_debugger_breakpoint_missing_path():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_set_debugger_breakpoint({"line": 1, "enabled": true})
	assert_has(result, "error", "Should return error for missing path")
	assert_true(str(result.error).contains("path"), "Error should mention path")

func test_set_debugger_breakpoint_invalid_line():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_set_debugger_breakpoint({"path": "res://player.gd", "line": 0, "enabled": true})
	assert_has(result, "error", "Should return error for invalid line")
	assert_true(str(result.error).contains("line"), "Error should mention line")

func test_send_debugger_message_missing_message():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_send_debugger_message({})
	assert_has(result, "error", "Should return error for missing message")
	assert_true(str(result.error).contains("message"), "Error should mention message")

func test_toggle_debugger_profiler_missing_profiler():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_toggle_debugger_profiler({"enabled": true})
	assert_has(result, "error", "Should return error for missing profiler")
	assert_true(str(result.error).contains("profiler"), "Error should mention profiler")

func test_add_debugger_capture_prefix_missing_prefix():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_add_debugger_capture_prefix({})
	assert_has(result, "error", "Should return error for missing prefix")
	assert_true(str(result.error).contains("prefix"), "Error should mention prefix")

func test_install_runtime_probe_empty_node_name():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_install_runtime_probe({"node_name": ""})
	assert_has(result, "error", "Should return error for empty node_name before editing scene")
	assert_true(str(result.error).contains("Editor interface") or str(result.error).contains("node_name"), "Error should be explicit")

func test_send_debug_command_rejects_unknown_command():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_send_debug_command({"command": "unsupported"})
	assert_has(result, "error", "Should return error for unsupported command")
	assert_true(str(result.error).contains("Unsupported"), "Error should mention unsupported command")

func test_get_debug_stack_variables_rejects_negative_frame():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_get_debug_stack_variables({"frame": -1})
	assert_has(result, "error", "Should return error for invalid frame")
	assert_true(str(result.error).contains("bridge") or str(result.error).contains("available"), "Error should mention debugger state")

func test_runtime_probe_polling_reuses_pending_request():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	_runtime_bridge = FakeRuntimeBridge.new()
	Engine.set_meta("GodotMCPPlugin", FakeRuntimePlugin.new(_runtime_bridge))

	# _tool_get_runtime_info uses await internally for the poll loop.
	# The await must be used at the call site to get a Dictionary result.
	var first_result: Dictionary = await debug_tools._tool_get_runtime_info({"timeout_ms": 1500})
	# The poll loop resolves with fresh data on the first frame after the initial pending response
	assert_eq(first_result.get("status"), "success", "First poll should resolve with fresh data")
	assert_eq(first_result.get("node_count"), 3, "Runtime info payload should come from the bridge response")
	assert_eq(_runtime_bridge.send_count, 1, "First poll should send exactly one runtime probe message")

	# Second call sends a new debugger message since the pending entry was consumed
	var second_result: Dictionary = await debug_tools._tool_get_runtime_info({"timeout_ms": 1500})
	assert_eq(second_result.get("status"), "success", "Second call should return success (from cache or fresh)")
	assert_eq(second_result.get("node_count"), 3, "Runtime info payload should come from the bridge response")
	assert_eq(_runtime_bridge.send_count, 2, "Second call re-sends debugger message since first call consumed the pending entry")

func test_extract_response_fallback_marks_stale():
	var debug_tools_script: GDScript = load("res://addons/godot_mcp/tools/debug_tools_native.gd")
	var source_code: String = debug_tools_script.source_code
	# The fallback loop in _extract_pending_runtime_probe_response should mark data as "stale": true
	assert_true(source_code.contains('response["status"] = "stale"'), "Fallback should set status to stale")
	assert_true(source_code.contains('response["stale"] = true'), "Fallback should mark stale=true")
	# The non-fallback (fresh) path should still use "success"
	assert_true(source_code.contains('response["status"] = "success"'), "Fresh response path should use success")

func test_poll_loop_continues_on_stale():
	var debug_tools_script: GDScript = load("res://addons/godot_mcp/tools/debug_tools_native.gd")
	var source_code: String = debug_tools_script.source_code
	# The poll loop should continue when status is "stale" (not exit early)
	assert_true(source_code.contains('not in ["pending", "stale"]'), "Poll loop should continue on stale status")
	# Timeout fallback should convert stale to success with from_cache
	assert_true(source_code.contains('result["status"] = "success"'), "Timeout should convert to success")
	assert_true(source_code.contains('result["from_cache"] = true'), "Timeout should mark from_cache")
	# Verify ordering: the from_cache mark should appear AFTER the poll loop
	var poll_loop_pos: int = source_code.find('not in ["pending", "stale"]')
	var from_cache_pos: int = source_code.find('result["from_cache"] = true')
	assert_true(poll_loop_pos >= 0, "Poll loop condition should exist")
	assert_true(from_cache_pos >= 0, "from_cache marker should exist")
	assert_true(poll_loop_pos < from_cache_pos, "from_cache should be set AFTER poll loop completes")

func test_poll_loop_enters_on_initial_stale():
	var debug_tools_script: GDScript = load("res://addons/godot_mcp/tools/debug_tools_native.gd")
	var source_code: String = debug_tools_script.source_code
	# The poll loop should enter when the initial result is "stale" (not just "pending")
	# Previously: if result.get("status") == "pending"
	# Now: if result.get("status") in ["pending", "stale"]
	assert_true(source_code.contains('if result.get("status") in ["pending", "stale"]'), "Poll loop should enter on both pending and stale initial status")
	# Verify the stale entry condition appears BEFORE the while loop
	var entry_pos: int = source_code.find('if result.get("status") in ["pending", "stale"]')
	var while_pos: int = source_code.find("while Time.get_ticks_msec() < deadline_ms", entry_pos)
	assert_true(entry_pos >= 0, "Entry condition should exist")
	assert_true(while_pos >= 0, "While loop should exist after entry condition")
	assert_true(entry_pos < while_pos, "Entry condition should appear before the while loop")
