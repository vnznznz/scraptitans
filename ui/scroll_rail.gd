class_name ScrollRail
extends Control

enum Pin { SHOWN, PINNED, AWAY }

const WIDTH := 20.0
const PIN_H := 44.0
const GAP := 2.0
const THUMB_W := 14.0
const THUMB_MIN := 20.0
const GRIP_W := 6.0
const IN_VIEW := 0.5
const JUMP_TIME := 0.3
const WHEEL_STEP := 40
const DIM := Color(1, 1, 1, 0.45)
const GLYPHS := [preload("res://art/ui/rail_field.png"), preload("res://art/ui/rail_yard.png")]
const ARROWS := [preload("res://art/ui/arrow_up.png"), preload("res://art/ui/arrow_down.png")]
const PIN_TEX := preload("res://art/ui/pin.png")
const STYLES := [&"", &"PinnedButton", &"AwayButton"]

@export var scroll: ScrollContainer
@export var top: Control
@export var bottom: Control

var pinned := [false, false]

var _areas: Array[Control] = []
var _homes: Array[Node] = []
var _pins: Array[Button] = []
var _marks: Array[TextureRect] = []
var _drag := -1.0
var _hover := false
var _tween: Tween


func _ready() -> void:
	_areas = [top, bottom]
	var content := scroll.get_child(0)
	_homes = [content.get_child(top.get_index() + 1), content.get_child(bottom.get_index() + 1) if bottom.get_index() + 1 < content.get_child_count() else null]
	clip_contents = true
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)
	for i in 2:
		var b := Button.new()
		b.name = ["PinField", "PinYard"][i]
		b.set_anchors_and_offsets_preset(PRESET_TOP_LEFT if i == 0 else PRESET_BOTTOM_LEFT)
		b.offset_left = 0.0
		b.offset_right = WIDTH
		if i == 0:
			b.offset_top = GAP
			b.offset_bottom = GAP + PIN_H
		else:
			b.offset_top = -GAP - PIN_H
			b.offset_bottom = -GAP
		b.pressed.connect(_on_pin.bind(i))
		add_child(b)
		var box := VBoxContainer.new()
		box.name = "Icons"
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		box.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(box)
		var mark := TextureRect.new()
		mark.name = "Mark"
		mark.size_flags_horizontal = SIZE_SHRINK_CENTER
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		var glyph := TextureRect.new()
		glyph.name = "Glyph"
		glyph.texture = GLYPHS[i]
		glyph.size_flags_horizontal = SIZE_SHRINK_CENTER
		glyph.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(mark if i == 0 else glyph)
		box.add_child(glyph if i == 0 else mark)
		_pins.append(b)
		_marks.append(mark)


func pin_button(i: int) -> Button:
	return _pins[i]


func state(i: int) -> Pin:
	if pinned[i]:
		return Pin.PINNED
	return Pin.SHOWN if Sound.visible_share(_areas[i]) >= IN_VIEW else Pin.AWAY


func reach(c: Control) -> Control:
	if not is_visible_in_tree():
		return c
	for i in 2:
		if (_areas[i] == c or _areas[i].is_ancestor_of(c)) and state(i) == Pin.AWAY:
			return _pins[i]
	return c


func pin(i: int, on: bool) -> void:
	if pinned[i] == on:
		return
	var h := _areas[i].size.y
	_place(i, on)
	if on and i == 0:
		_scroll_later(scroll.scroll_vertical - roundi(h))
	elif not on:
		_scroll_later(0 if i == 0 else 1 << 30)


func release() -> void:
	for i in 2:
		if pinned[i]:
			_place(i, false)
	_scroll_later(0)


func _place(i: int, on: bool) -> void:
	pinned[i] = on
	var area := _areas[i]
	area.reparent(scroll.get_parent() if on else scroll.get_child(0), false)
	var home := _homes[i]
	if on or home == null:
		area.get_parent().move_child(area, 0 if i == 0 else -1)
	else:
		area.get_parent().move_child(area, home.get_index())


func jump(i: int) -> void:
	var bar := scroll.get_v_scroll_bar()
	var to := 0.0 if i == 0 else bar.max_value - bar.page
	_stop_jump()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: scroll.scroll_vertical = roundi(v),
			float(scroll.scroll_vertical), to, JUMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _scroll_later(v: int) -> void:
	_stop_jump()
	await get_tree().process_frame
	scroll.scroll_vertical = maxi(v, 0)


func _stop_jump() -> void:
	if _tween:
		_tween.kill()
		_tween = null


func _on_pin(i: int) -> void:
	match state(i):
		Pin.PINNED:
			pin(i, false)
		Pin.SHOWN:
			pin(i, true)
		Pin.AWAY:
			jump(i)


func _process(_delta: float) -> void:
	for i in 2:
		var s := state(i)
		var b := _pins[i]
		b.theme_type_variation = STYLES[s]
		_marks[i].texture = ARROWS[i] if s == Pin.AWAY else PIN_TEX
		_marks[i].modulate = DIM if s == Pin.SHOWN else Color.WHITE
		var mode := b.get_draw_mode()
		var sunk := s == Pin.PINNED or mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
		(b.get_node("Icons") as Control).position.y = 1.0 if sunk else 0.0
	queue_redraw()


func _track() -> Rect2:
	return Rect2(0, PIN_H + 2.0 * GAP, WIDTH, size.y - 2.0 * (PIN_H + 2.0 * GAP))


func _thumb() -> Rect2:
	var bar := scroll.get_v_scroll_bar()
	var span := bar.max_value - bar.page
	if span <= 0.0:
		return Rect2()
	var track := _track()
	var h := maxf(THUMB_MIN, roundf(track.size.y * bar.page / bar.max_value))
	var y := track.position.y + roundf((track.size.y - h) * scroll.scroll_vertical / span)
	return Rect2(roundf((WIDTH - THUMB_W) / 2.0), y, THUMB_W, h)


func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTH, size.y), Pal.SLATE_D)
	draw_rect(Rect2(0, 0, 1, size.y), Pal.INK)
	var track := _track()
	draw_style_box(get_theme_stylebox("scroll", "VScrollBar"), Rect2(roundf((WIDTH - THUMB_W) / 2.0), track.position.y, THUMB_W, track.size.y))
	var thumb := _thumb()
	if not thumb.has_area():
		return
	var look := "grabber_pressed" if _drag >= 0.0 else "grabber_highlight" if _hover and Hover.enabled() else "grabber"
	draw_style_box(get_theme_stylebox(look, "VScrollBar"), thumb)
	var cx := roundf(thumb.get_center().x - GRIP_W / 2.0)
	var cy := roundf(thumb.get_center().y) + (1.0 if _drag >= 0.0 else 0.0)
	for k in [-3, 0, 3]:
		draw_rect(Rect2(cx, cy + k - 1, GRIP_W, 1), Pal.INK)
		draw_rect(Rect2(cx, cy + k, GRIP_W, 1), Pal.SLATE)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_stop_jump()
		scroll.scroll_vertical += WHEEL_STEP * (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		accept_event()
	elif mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and _track().has_point(mb.position) and _thumb().has_area():
			var thumb := _thumb()
			_drag = mb.position.y - thumb.position.y if thumb.has_point(mb.position) else thumb.size.y / 2.0
			_drag_to(mb.position.y)
			accept_event()
		elif not mb.pressed:
			_drag = -1.0
	elif event is InputEventMouseMotion and _drag >= 0.0:
		_drag_to((event as InputEventMouseMotion).position.y)
		accept_event()


func _drag_to(y: float) -> void:
	_stop_jump()
	var track := _track()
	var span := track.size.y - _thumb().size.y
	var k := clampf((y - _drag - track.position.y) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var bar := scroll.get_v_scroll_bar()
	scroll.scroll_vertical = roundi(k * (bar.max_value - bar.page))
