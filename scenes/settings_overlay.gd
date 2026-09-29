class_name SettingsOverlay
extends Control

var _title: Label
var _reset: Button
var _confirm: Button
var _close: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	var version := Label.new()
	version.text = "BUILD " + str(ProjectSettings.get_setting("application/config/version"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.modulate = Color(1, 1, 1, 0.5)
	box.add_child(version)

	_reset = _button(box, "Reset", "RESET RUN", func() -> void: _show(true))
	_confirm = _button(box, "Confirm", "YES, RESET", Save.reset_run)
	_close = _button(box, "Close", "CLOSE", close)


func open() -> void:
	_show(false)
	visible = true


func close() -> void:
	if _confirm.visible:
		_show(false)
	else:
		visible = false


func _show(confirming: bool) -> void:
	_title.text = "RESET RUN?\nALL PROGRESS IS LOST" if confirming else "SETTINGS"
	_reset.visible = not confirming
	_confirm.visible = confirming
	_close.text = "CANCEL" if confirming else "CLOSE"


func _button(box: Control, node_name: String, label: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = label
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	box.add_child(b)
	return b
