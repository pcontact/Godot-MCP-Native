# Quick Start

Godot Agent Tools exposes the existing editor tools through an internal registry for AI coding agents running inside the Godot editor. It does not start an MCP, HTTP, stdio, or JSON-RPC server.

## Enable The Plugin

1. Copy `addons/godot_mcp` into your project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Godot Agent Tools**.
4. Open the **Agent Tools** main-screen panel to manage tool groups and settings.

## Call Tools Directly

Use the plugin instance stored on `Engine`:

```gdscript
var plugin = Engine.get_meta("GodotAgentToolsPlugin")
var registry = plugin.get_tool_registry()

var tools: Array = registry.list_tools(true)
var result: Dictionary = await registry.call_tool("get_project_info", {})
```

`call_tool()` returns the raw `Dictionary` from the tool implementation. Missing or disabled tools return:

```gdscript
{"error": "Tool not found: missing_tool"}
{"error": "Tool is disabled: tool_name"}
```

## Manage Availability

Core tools are enabled by default. Supplementary tools are registered but disabled until explicitly enabled.

```gdscript
registry.set_tool_enabled("list_project_tests", true)
registry.set_group_enabled("Project-Advanced", true)
```

Tool states are persisted with `AgentToolStateManager` in `agent_tool_state.cfg`; legacy `mcp_tool_state.cfg` is read for migration compatibility.
