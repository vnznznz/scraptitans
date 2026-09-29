extends Control

@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: VBoxContainer = %Content
@onready var _settings: SettingsOverlay = %Settings


func _ready() -> void:
	for i in GameState.lines.size():
		var v := LineView.new()
		v.name = "Line%d" % i
		v.line_index = i
		_content.add_child(v)
		_content.move_child(v, i)
	%Hud.settings_pressed.connect(_settings.open)
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func line_view(i: int) -> LineView:
	return _content.get_node("Line%d" % i)
