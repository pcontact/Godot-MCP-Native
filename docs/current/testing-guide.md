# Testing Guide

Tests target the direct in-editor agent registry. Transport, HTTP, stdio, auth, and JSON-RPC protocol tests have been removed with the server layer.

## Unit Tests

Run the unit suite with GUT:

```powershell
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

Important registry coverage lives in:

- `test/unit/test_agent_tool_registry.gd`
- `test/unit/test_agent_types.gd`
- `test/unit/test_tool_state_manager.gd`
- `test/unit/test_mcp_tool_classifier.gd`
- `test/unit/tools/`

## Expected Coverage

- Tool registration preserves metadata, schemas, category, group, and default enabled state.
- `call_tool()` returns raw dictionaries for sync and async tools.
- Disabled and missing tools return direct error dictionaries.
- Group toggles and individual tool toggles persist through `AgentToolStateManager`.
- Tool modules continue to validate missing params, invalid params, edge cases, and error handling.

## Cleanup

After running tests or modifying code, remove temporary files that can confuse the Godot script scanner:

- `.codeartsdoer/temp/*.gd`
- root `.tmp_*` directories
- `test/integration/.tmp_*` directories
