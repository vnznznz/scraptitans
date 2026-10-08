class_name DebugPanel
extends Control

var _panel: PanelContainer
var _toggle: Button
var _speed: Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	var toggle := Button.new()
	_toggle = toggle
	toggle.name = "DebugToggle"
	toggle.text = "DBG"
	toggle.position = Vector2(4, 76)
	toggle.size = Vector2(56, 32)
	toggle.modulate = Color(1, 1, 1, 0.6)
	toggle.pressed.connect(func() -> void:
		_panel.visible = not _panel.visible
		_panel.position.y = toggle.get_rect().end.y + 4)
	add_child(toggle)

	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.position = Vector2(4, 0)
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
	_button(grants, "+100K SCRAP", func() -> void: GameState.scrap += 100000)
	var more := HBoxContainer.new()
	box.add_child(more)
	_button(more, "+1K CR", func() -> void: GameState.credits += 1000)
	_button(more, "+1M CR", func() -> void: GameState.credits += 1000000)
	var field := HBoxContainer.new()
	box.add_child(field)
	_button(field, "KILL WAVE", GameState.kill_wave)
	_button(field, "+50 MECHS", GameState.debug_spawn_mechs.bind(50))
	var wars := HBoxContainer.new()
	box.add_child(wars)
	_button(wars, "+1 WAR WON", Save.start_again)
	_button(wars, "0 WARS WON", Save.reset_save)
	var away := HBoxContainer.new()
	box.add_child(away)
	_button(away, "10 MIN AWAY", GameState.away.bind(600.0))
	_button(away, "2 H AWAY", GameState.away.bind(7200.0))


func _process(_delta: float) -> void:
	_toggle.visible = not get_tree().get_first_node_in_group("upgrade_menu").visible
	if _panel.visible:
		_speed.text = "X%d  MECHS %d  WARS %d" % [GameState.time_scale, GameState.field.size(), GameState.prestige]


func _button(parent: Control, label: String, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(action)
	parent.add_child(b)
