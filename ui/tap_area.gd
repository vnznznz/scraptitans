class_name TapArea
extends Control

signal tapped(at: Vector2)

const HOLD_RATE := 5.0

var highlight: CanvasItem

var _hold := Hold.new(1.0 / HOLD_RATE, 1.0 / HOLD_RATE)
var _inside := false
var _down := false
var _space := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_PASS


func _ready() -> void:
	Hover.add(self, highlight)
	mouse_entered.connect(func() -> void: _inside = true)
	mouse_exited.connect(func() -> void: _inside = false)
	set_process(Hover.enabled())
	set_process_input(Hover.enabled())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		_down = true
		tapped.emit(event.position)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_down = false
	elif event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		_space = event.pressed
		if _space and _inside and is_visible_in_tree():
			tapped.emit(get_local_mouse_position())


func _process(delta: float) -> void:
	if _hold.step((_down or _space) and _inside and is_visible_in_tree(), delta):
		tapped.emit(get_local_mouse_position())
