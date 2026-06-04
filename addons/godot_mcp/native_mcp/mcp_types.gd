class_name AgentTypes
extends RefCounted

enum LogLevel {
	ERROR,
	WARN,
	INFO,
	DEBUG
}

enum SecurityLevel {
	PERMISSIVE,
	STRICT
}

class AgentTool:
	var name: String = ""
	var description: String = ""
	var input_schema: Dictionary = {}
	var output_schema: Dictionary = {}
	var annotations: Dictionary = {}
	var callable: Callable = Callable()
	var enabled: bool = true
	var category: String = "core"
	var group: String = ""

	func to_dict() -> Dictionary:
		var result: Dictionary = {
			"name": name,
			"description": description,
			"inputSchema": input_schema,
			"enabled": enabled,
			"category": category,
			"group": group
		}

		if not output_schema.is_empty():
			result["outputSchema"] = output_schema

		if not annotations.is_empty():
			result["annotations"] = annotations

		return result

	func is_valid() -> bool:
		return not name.is_empty() and not description.is_empty() and callable.is_valid()

	static func create_annotations(read_only: bool = false, destructive: bool = false, idempotent: bool = false, open_world: bool = false) -> Dictionary:
		return {
			"readOnlyHint": read_only,
			"destructiveHint": destructive,
			"idempotentHint": idempotent,
			"openWorldHint": open_world
		}

class AgentResource:
	var uri: String = ""
	var name: String = ""
	var description: String = ""
	var mime_type: String = "application/octet-stream"
	var load_callable: Callable = Callable()

	func to_dict() -> Dictionary:
		var result: Dictionary = {
			"uri": uri,
			"name": name,
			"mimeType": mime_type
		}

		if not description.is_empty():
			result["description"] = description

		return result

	func is_valid() -> bool:
		return not uri.is_empty() and not name.is_empty() and load_callable.is_valid()

class AgentPrompt:
	var name: String = ""
	var description: String = ""
	var arguments: Array[Dictionary] = []

	func to_dict() -> Dictionary:
		return {
			"name": name,
			"description": description,
			"arguments": arguments
		}

	func is_valid() -> bool:
		return not name.is_empty()

static func is_path_safe(path: String) -> bool:
	var allowed_prefixes: Array[String] = ["res://", "user://"]
	var is_allowed: bool = false

	for prefix in allowed_prefixes:
		if path.begins_with(prefix):
			is_allowed = true
			break

	if not is_allowed:
		return false

	var blocked_patterns: Array[String] = ["..", "~", "$", "|", ";", "`", "&&", "||"]
	for pattern in blocked_patterns:
		if path.contains(pattern):
			return false

	return path.length() <= 4096

static func sanitize_path(path: String) -> String:
	var sanitized: String = path.replace("..", "").replace("~", "")

	if not sanitized.begins_with("res://") and not sanitized.begins_with("user://"):
		sanitized = "res://" + sanitized.lstrip("/")

	return sanitized
