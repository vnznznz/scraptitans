class_name Hover

const TINT := Color(1.25, 1.25, 1.2)


static func enabled() -> bool:
	return not DisplayServer.is_touchscreen_available()


static func add(control: Control, target: CanvasItem) -> void:
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not enabled() or target == null:
		return
	control.mouse_entered.connect(func() -> void: target.self_modulate = TINT)
	control.mouse_exited.connect(func() -> void: target.self_modulate = Color.WHITE)


static func button(b: BaseButton) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func() -> void:
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW if b.disabled else Control.CURSOR_POINTING_HAND)
	if b is Button and (b as Button).flat and enabled():
		b.mouse_entered.connect(func() -> void: b.self_modulate = TINT)
		b.mouse_exited.connect(func() -> void: b.self_modulate = Color.WHITE)
