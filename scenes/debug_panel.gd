class_name DebugPanel
extends Control

var _panel: PanelContainer
var _speed: Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	var toggle := Button.new()
	toggle.name = "DebugToggle"
	toggle.text = "DBG"
	toggle.position = Vector2(4, 36)
	toggle.size = Vector2(36, 24)
	toggle.modulate = Color(1, 1, 1, 0.6)
	toggle.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	add_child(toggle)

	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.position = Vector2(4, 64)
	_panel.visible = false
	add_child(_panel)

	var box := VBoxContainer.new()
	_panel.add_child(box)
	_speed = Label.new()
	box.add_child(_speed)
	var speeds := HBoxContainer.new()
	box.add_child(speeds)
	for s in [1.0, 10.0, 100.0]:
		_button(speeds, "X%d" % s, func() -> void: GameState.time_scale = s)
	var grants := HBoxContainer.new()
	box.add_child(grants)
	_button(grants, "+100 SCRAP", func() -> void: GameState.scrap += 100)
	_button(grants, "+10K SCRAP", func() -> void: GameState.scrap += 10000)
	_button(box, "+1K CREDITS", func() -> void: GameState.credits += 1000)


func _process(_delta: float) -> void:
	if _panel.visible:
		_speed.text = "SPEED X%d  MECHS %d" % [GameState.time_scale, GameState.field.size()]


func _button(parent: Control, label: String, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(action)
	parent.add_child(b)
