class_name TapArea
extends Control

signal tapped(at: Vector2)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		tapped.emit(event.position)
