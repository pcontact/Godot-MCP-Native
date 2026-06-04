# Architecture

Godot Agent Tools is an in-editor tool registry for AI coding agents. The former MCP transport layer has been removed: there is no HTTP listener, stdio process protocol, JSON-RPC handler, auth manager, or rate limiter.

## Runtime Shape

```text
AI agent running in Godot editor
        |
        v
EditorPlugin: Godot Agent Tools
        |
        v
AgentToolRegistry.call_tool(name, params)
        |
        v
addons/godot_mcp/tools/*_native.gd
```

## Main Components

- `mcp_server_native.gd`: EditorPlugin entrypoint. It initializes the direct registry, registers tool modules/resources, installs the runtime probe autoload, and exposes `get_tool_registry()`.
- `native_mcp/mcp_server_core.gd`: `AgentToolRegistry`. It stores tool metadata, manages enabled state, and calls tool `Callable`s directly.
- `native_mcp/mcp_types.gd`: `AgentTypes`. It defines `AgentTool`, `AgentResource`, `AgentPrompt`, log levels, and path helpers.
- `native_mcp/mcp_tool_classifier.gd`: `AgentToolClassifier`. It keeps the 154-tool classification map.
- `native_mcp/tool_state_manager.gd`: `AgentToolStateManager`. It persists enabled/disabled tool state and reads the legacy MCP state file for migration.
- `tools/*_native.gd`: Core tool implementations. These still register through `register_tool(...)` so the tool logic remains decoupled from the caller.

## Direct API

```gdscript
var plugin = Engine.get_meta("GodotAgentToolsPlugin")
var registry = plugin.get_tool_registry()

var tools: Array = registry.list_tools(true)
var result: Dictionary = await registry.call_tool("get_project_info", {})
```

The registry emits:

- `tool_execution_started(tool_name, params)`
- `tool_execution_completed(tool_name, result)`
- `tool_execution_failed(tool_name, error)`
- `resource_requested(resource_uri, params)`
- `resource_loaded(resource_uri, content)`
- `log_message(level, message)`

## Tool Results

`call_tool()` returns raw tool dictionaries. It does not wrap output in protocol envelopes. Registry-level failures use direct error dictionaries:

```gdscript
{"error": "Tool not found: missing_tool"}
{"error": "Tool is disabled: tool_name"}
```
