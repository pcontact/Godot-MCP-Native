@tool
extends VBoxContainer

var _plugin: EditorPlugin = null
var _tool_registry: RefCounted = null

var _status_label: Label = null
var _log_level_option: OptionButton = null
var _security_level_option: OptionButton = null
var _log_text_edit: TextEdit = null
var _tools_list_container: VBoxContainer = null
var _tools_count_label: Label = null
var _log_level_label: Label = null
var _security_label: Label = null
var _language_label: Label = null
var _clear_log_button: Button = null
var _refresh_tools_button: Button = null
var _vibe_coding_mode_check: CheckBox = null
var _tab_container: TabContainer = null
var _debounce_timer: Timer = null
var _group_widgets: Dictionary = {}
var _language_option: OptionButton = null
var _log_buffer: Array[String] = []
var _max_log_lines: int = 100
var _translation_manager: MCPTranslationManager = null
var _settings_manager: AgentSettingsManager = null

func _ready() -> void:
	_translation_manager = MCPTranslationManager.new()
	_translation_manager.load_all()
	_settings_manager = AgentSettingsManager.new()
	_create_ui()
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.timeout.connect(_on_debounce_timeout)
	add_child(_debounce_timer)

func _exit_tree() -> void:
	if _debounce_timer:
		_debounce_timer.stop()

func set_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin
	if _plugin and _plugin.has_method("get_tool_registry"):
		_tool_registry = _plugin.get_tool_registry()
	_load_settings()
	_refresh_translations()

func set_tool_registry(tool_registry: RefCounted) -> void:
	_tool_registry = tool_registry
	_update_ui_state()
	_refresh_tools_list()

func set_server_core(tool_registry: RefCounted) -> void:
	set_tool_registry(tool_registry)

func _tr(key: String) -> String:
	if _translation_manager:
		return _translation_manager.get_text(key)
	return key

func _trf(key: String, args: Array) -> String:
	var text: String = _tr(key)
	var placeholder_count: int = 0
	for i in text.length():
		if text[i] == "%":
			i += 1
			if i < text.length() and text[i] in "dsf":
				placeholder_count += 1
	if placeholder_count > 0 and placeholder_count == args.size():
		return text % args
	return text

func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	add_child(_create_status_bar())

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)

	_tab_container.add_child(_create_settings_tab())
	_tab_container.add_child(_create_log_tab())
	_tab_container.add_child(_create_tools_tab())

	_refresh_translations()
	_update_ui_state()
	_refresh_tools_list()

func _create_status_bar() -> HBoxContainer:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	_status_label = Label.new()
	_status_label.text = _tr("ui.status_ready")
	_status_label.add_theme_font_size_override("font_size", 14)
	bar.add_child(_status_label)

	_refresh_tools_button = Button.new()
	_refresh_tools_button.text = _tr("ui.refresh_tools")
	_refresh_tools_button.pressed.connect(_refresh_tools_list)
	bar.add_child(_refresh_tools_button)

	return bar

func _create_settings_tab() -> VBoxContainer:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 6)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_vibe_coding_mode_check = CheckBox.new()
	_vibe_coding_mode_check.text = _tr("ui.vibe_coding_mode")
	_vibe_coding_mode_check.toggled.connect(_on_vibe_coding_mode_toggled)
	content.add_child(_vibe_coding_mode_check)

	var log_hbox: HBoxContainer = HBoxContainer.new()
	content.add_child(log_hbox)

	_log_level_label = Label.new()
	_log_level_label.text = _tr("ui.log_level")
	log_hbox.add_child(_log_level_label)

	_log_level_option = OptionButton.new()
	_log_level_option.add_item("ERROR", 0)
	_log_level_option.add_item("WARN", 1)
	_log_level_option.add_item("INFO", 2)
	_log_level_option.add_item("DEBUG", 3)
	_log_level_option.item_selected.connect(_on_log_level_selected)
	log_hbox.add_child(_log_level_option)

	var security_hbox: HBoxContainer = HBoxContainer.new()
	content.add_child(security_hbox)

	_security_label = Label.new()
	_security_label.text = _tr("ui.security")
	security_hbox.add_child(_security_label)

	_security_level_option = OptionButton.new()
	_security_level_option.add_item("PERMISSIVE", 0)
	_security_level_option.add_item("STRICT", 1)
	_security_level_option.item_selected.connect(_on_security_level_selected)
	security_hbox.add_child(_security_level_option)

	var language_hbox: HBoxContainer = HBoxContainer.new()
	content.add_child(language_hbox)

	_language_label = Label.new()
	_language_label.text = _tr("ui.language")
	language_hbox.add_child(_language_label)

	_language_option = OptionButton.new()
	_language_option.add_item(_tr("ui.english"), 0)
	_language_option.add_item(_tr("ui.chinese"), 1)
	_language_option.item_selected.connect(_on_language_selected)
	language_hbox.add_child(_language_option)

	return tab

func _create_log_tab() -> VBoxContainer:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 6)

	var toolbar: HBoxContainer = HBoxContainer.new()
	tab.add_child(toolbar)

	_clear_log_button = Button.new()
	_clear_log_button.text = _tr("ui.clear_log")
	_clear_log_button.pressed.connect(_on_clear_log_pressed)
	toolbar.add_child(_clear_log_button)

	_log_text_edit = TextEdit.new()
	_log_text_edit.editable = false
	_log_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(_log_text_edit)

	return tab

func _create_tools_tab() -> VBoxContainer:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 6)

	_tools_count_label = Label.new()
	_tools_count_label.text = _tr("ui.tools_init")
	tab.add_child(_tools_count_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	_tools_list_container = VBoxContainer.new()
	_tools_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_tools_list_container)

	return tab

func _update_ui_state() -> void:
	if _status_label:
		_status_label.text = _tr("ui.status_ready") if _tool_registry else _tr("ui.status_unknown")

	if _plugin:
		if _vibe_coding_mode_check:
			_vibe_coding_mode_check.button_pressed = _plugin.vibe_coding_mode if _plugin.get("vibe_coding_mode") != null else true
		if _log_level_option:
			_log_level_option.select(_plugin.log_level if _plugin.get("log_level") != null else 2)
		if _security_level_option:
			_security_level_option.select(_plugin.security_level if _plugin.get("security_level") != null else 1)

func _refresh_tools_list() -> void:
	if not _tools_list_container:
		return

	for child in _tools_list_container.get_children():
		child.queue_free()
	_group_widgets.clear()

	var tools: Array = []
	if _tool_registry and _tool_registry.has_method("get_registered_tools"):
		tools = _tool_registry.get_registered_tools()

	var classifier = null
	if _tool_registry and _tool_registry.has_method("get_classifier"):
		classifier = _tool_registry.get_classifier()

	var tools_by_group: Dictionary = {}
	for tool_info in tools:
		var group: String = tool_info.get("group", "")
		if not tools_by_group.has(group):
			tools_by_group[group] = []
		tools_by_group[group].append(tool_info)

	var all_groups: Array = []
	if classifier and classifier.has_method("get_all_groups"):
		all_groups = classifier.get_all_groups()

	var core_group_names: Array = []
	var supp_group_names: Array = []
	for group_name in all_groups:
		if tools_by_group.has(group_name):
			var sample: Dictionary = tools_by_group[group_name][0]
			if sample.get("category", "core") == "supplementary":
				supp_group_names.append(group_name)
			else:
				core_group_names.append(group_name)

	if core_group_names.size() > 0:
		var core_section: Label = Label.new()
		core_section.text = _tr("ui.core_tools")
		core_section.add_theme_font_size_override("font_size", 14)
		_tools_list_container.add_child(core_section)
		for group_name in core_group_names:
			_create_group_widget(group_name, tools_by_group[group_name])

	if supp_group_names.size() > 0:
		var supp_section: Label = Label.new()
		supp_section.text = _tr("ui.supplementary_tools")
		supp_section.add_theme_font_size_override("font_size", 14)
		_tools_list_container.add_child(supp_section)
		for group_name in supp_group_names:
			_create_group_widget(group_name, tools_by_group[group_name])

	_update_tools_count()

func _create_group_widget(group_name: String, group_tools: Array) -> void:
	var widget: MCPToolGroupItem = MCPToolGroupItem.new()
	widget.setup(group_name, group_tools, _translation_manager)
	widget.group_toggled.connect(_on_group_toggled)
	widget.item_toggled.connect(_on_tool_toggled)
	_tools_list_container.add_child(widget)
	_group_widgets[group_name] = widget

func _on_tool_toggled(tool_name: String, enabled: bool) -> void:
	if _tool_registry and _tool_registry.has_method("set_tool_enabled"):
		_tool_registry.set_tool_enabled(tool_name, enabled)
	_update_tools_count()
	_debounce_save()

func _on_group_toggled(group_name: String, enabled: bool) -> void:
	if _tool_registry and _tool_registry.has_method("set_group_enabled"):
		_tool_registry.set_group_enabled(group_name, enabled)
	_update_tools_count()
	_debounce_save()

func _update_tools_count() -> void:
	if not _tools_count_label:
		return

	var tools: Array = []
	if _tool_registry and _tool_registry.has_method("get_registered_tools"):
		tools = _tool_registry.get_registered_tools()

	var core_total: int = 0
	var core_enabled: int = 0
	var supp_total: int = 0
	var supp_enabled: int = 0
	for tool_info in tools:
		var enabled: bool = tool_info.get("enabled", true)
		if tool_info.get("category", "core") == "supplementary":
			supp_total += 1
			if enabled:
				supp_enabled += 1
		else:
			core_total += 1
			if enabled:
				core_enabled += 1

	_tools_count_label.text = _trf("ui.tools_count", [core_enabled, core_total, supp_enabled, supp_total, core_enabled + supp_enabled, core_total + supp_total])

func _on_vibe_coding_mode_toggled(button_pressed: bool) -> void:
	if _plugin:
		_plugin.vibe_coding_mode = button_pressed
	_debounce_save()

func _on_log_level_selected(index: int) -> void:
	if _plugin:
		_plugin.log_level = index
	_debounce_save()

func _on_security_level_selected(index: int) -> void:
	if _plugin:
		_plugin.security_level = index
	_debounce_save()

func _on_clear_log_pressed() -> void:
	clear_log()

func clear_log() -> void:
	_log_buffer.clear()
	if _log_text_edit:
		_log_text_edit.text = ""

func _refresh_translations() -> void:
	if _tab_container:
		_tab_container.set_tab_title(0, _tr("ui.settings"))
		_tab_container.set_tab_title(1, _tr("ui.agent_log"))
		_tab_container.set_tab_title(2, _tr("ui.tool_manager"))
	if _status_label:
		_status_label.text = _tr("ui.status_ready") if _tool_registry else _tr("ui.status_unknown")
	if _clear_log_button:
		_clear_log_button.text = _tr("ui.clear_log")
	if _refresh_tools_button:
		_refresh_tools_button.text = _tr("ui.refresh_tools")
	if _vibe_coding_mode_check:
		_vibe_coding_mode_check.text = _tr("ui.vibe_coding_mode")
	if _log_level_label:
		_log_level_label.text = _tr("ui.log_level")
	if _security_label:
		_security_label.text = _tr("ui.security")
	if _language_label:
		_language_label.text = _tr("ui.language")
	if _language_option:
		var current_locale: String = _translation_manager.get_locale() if _translation_manager else "en"
		var locales: Array = _translation_manager.get_available_locales() if _translation_manager else ["en", "zh"]
		_language_option.set_block_signals(true)
		_language_option.clear()
		_language_option.add_item(_tr("ui.english"), 0)
		_language_option.add_item(_tr("ui.chinese"), 1)
		var idx: int = locales.find(current_locale)
		if idx >= 0:
			_language_option.select(idx)
		_language_option.set_block_signals(false)
	if _tools_count_label:
		_tools_count_label.text = _tr("ui.tools_init")
	_update_ui_state()
	_refresh_tools_list()

func _load_settings() -> void:
	if not _settings_manager:
		return
	var settings: Dictionary = _settings_manager.load_settings()
	if _log_level_option:
		_log_level_option.select(settings.log_level)
	if _security_level_option:
		_security_level_option.select(settings.security_level)
	if _translation_manager and settings.language != _translation_manager.get_locale():
		_translation_manager.set_locale(settings.language)

func _save_settings() -> void:
	if not _settings_manager:
		return
	_settings_manager.save_settings({
		"log_level": _log_level_option.selected if _log_level_option else 2,
		"security_level": _security_level_option.selected if _security_level_option else 1,
		"language": _translation_manager.get_locale() if _translation_manager else "en"
	})

func _on_language_selected(index: int) -> void:
	var locales: Array = _translation_manager.get_available_locales() if _translation_manager else ["en", "zh"]
	if index >= 0 and index < locales.size():
		_translation_manager.set_locale(locales[index])
		_refresh_translations()
	_debounce_save()

func _debounce_save() -> void:
	if _debounce_timer:
		_debounce_timer.start(0.5)

func _on_debounce_timeout() -> void:
	if _tool_registry and _tool_registry.has_method("save_tool_states"):
		_tool_registry.save_tool_states()
	if _tool_registry and _tool_registry.has_method("notify_tool_list_changed"):
		_tool_registry.notify_tool_list_changed()
	_save_settings()

func update_log(message: String) -> void:
	if not _log_text_edit:
		return
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		_append_log(message)
	else:
		call_deferred("_append_log", message)

func _append_log(message: String) -> void:
	_log_buffer.append(message)
	while _log_buffer.size() > _max_log_lines:
		_log_buffer.pop_front()
	if _log_text_edit:
		_log_text_edit.text = "\n".join(_log_buffer)
		_log_text_edit.scroll_vertical = _log_text_edit.get_line_count()

func refresh() -> void:
	_update_ui_state()
	_refresh_tools_list()
