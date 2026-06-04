extends "res://addons/gut/test.gd"

func test_agent_tool_info_valid():
	var tool: AgentTypes.AgentTool = AgentTypes.AgentTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	assert_true(tool.is_valid(), "Tool with all fields should be valid")
	assert_true(tool.enabled, "Newly created tool should be enabled by default")
	assert_eq(tool.category, "core", "Default category should be 'core'")
	assert_eq(tool.group, "", "Default group should be empty")

func test_agent_tool_category_field():
	var tool: AgentTypes.AgentTool = AgentTypes.AgentTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	tool.category = "supplementary"
	assert_eq(tool.category, "supplementary", "Category should be settable")
	assert_true(tool.is_valid(), "Tool with supplementary category should still be valid")

func test_agent_tool_group_field():
	var tool: AgentTypes.AgentTool = AgentTypes.AgentTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	tool.group = "Node-Read"
	assert_eq(tool.group, "Node-Read", "Group should be settable")
	assert_true(tool.is_valid(), "Tool with group should still be valid")

func test_agent_tool_to_dict():
	var tool: AgentTypes.AgentTool = AgentTypes.AgentTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.input_schema = {"type": "object"}
	tool.output_schema = {"type": "object"}
	tool.annotations = AgentTypes.AgentTool.create_annotations(true, false, true, false)
	var d: Dictionary = tool.to_dict()
	assert_eq(d["name"], "test_tool", "Dict should have correct name")
	assert_eq(d["description"], "A test tool", "Dict should have correct description")
	assert_has(d, "inputSchema", "Dict should have inputSchema")
	assert_has(d, "outputSchema", "Dict should have outputSchema")
	assert_has(d, "annotations", "Dict should have annotations")
	assert_eq(d["annotations"]["readOnlyHint"], true, "readOnlyHint should be true")

func test_agent_tool_missing_fields_invalid():
	var tool: AgentTypes.AgentTool = AgentTypes.AgentTool.new()
	assert_false(tool.is_valid(), "Tool without fields should be invalid")
	tool.name = "test_tool"
	assert_false(tool.is_valid(), "Tool without description/callable should be invalid")
	tool.description = "A test tool"
	assert_false(tool.is_valid(), "Tool without callable should be invalid")

func test_agent_resource_valid():
	var res: AgentTypes.AgentResource = AgentTypes.AgentResource.new()
	res.uri = "godot://scene/list"
	res.name = "Scene List"
	res.load_callable = func(params): return {}
	assert_true(res.is_valid(), "Resource with all fields should be valid")

func test_agent_resource_to_dict():
	var res: AgentTypes.AgentResource = AgentTypes.AgentResource.new()
	res.uri = "godot://scene/list"
	res.name = "Scene List"
	res.mime_type = "application/json"
	res.description = "List scenes"
	var d: Dictionary = res.to_dict()
	assert_eq(d["uri"], "godot://scene/list", "Dict should have correct uri")
	assert_eq(d["name"], "Scene List", "Dict should have correct name")
	assert_eq(d["mimeType"], "application/json", "Dict should have correct mimeType")
	assert_eq(d["description"], "List scenes", "Dict should include description")

func test_agent_resource_missing_fields_invalid():
	var res: AgentTypes.AgentResource = AgentTypes.AgentResource.new()
	assert_false(res.is_valid(), "Resource without fields should be invalid")
	res.uri = "godot://scene/list"
	res.name = "Scene List"
	assert_false(res.is_valid(), "Resource without callable should be invalid")

func test_agent_prompt_valid():
	var prompt: AgentTypes.AgentPrompt = AgentTypes.AgentPrompt.new()
	prompt.name = "test_prompt"
	assert_true(prompt.is_valid(), "Prompt with name should be valid")

func test_agent_prompt_missing_name():
	var prompt: AgentTypes.AgentPrompt = AgentTypes.AgentPrompt.new()
	assert_false(prompt.is_valid(), "Prompt without name should be invalid")

func test_is_path_safe_valid():
	assert_true(AgentTypes.is_path_safe("res://test.tscn"), "res:// path should be safe")

func test_is_path_safe_traversal():
	assert_false(AgentTypes.is_path_safe("res://../etc/passwd"), "Traversal path should be unsafe")

func test_is_path_safe_absolute():
	assert_false(AgentTypes.is_path_safe("/etc/passwd"), "Absolute path should be unsafe")

func test_sanitize_path():
	var result: String = AgentTypes.sanitize_path("res://test../file.gd")
	assert_false(result.contains(".."), "Should remove .. from path")

func test_sanitize_path_adds_prefix():
	var result: String = AgentTypes.sanitize_path("test.gd")
	assert_true(result.begins_with("res://"), "Should add res:// prefix")
