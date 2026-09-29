class_name IntroGuide
extends Control

const COLOR := Color(1.0, 0.85, 0.3)
const OUTLINE := Color(0.08, 0.07, 0.1)
const ARROW := Vector2(8, 10)
const MARGIN := 16.0

var pile: Control
var line: LineView

var _label: Label
var _tip := Vector2.ZERO
var _down := false
var _arrow := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Text"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_color_override("font_color", COLOR)
	_label.add_theme_color_override("font_outline_color", OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func text() -> String:
	return _label.text if visible else ""


func _process(delta: float) -> void:
	var step := _step()
	visible = not step.is_empty()
	if not visible:
		return
	_t += delta
	var bob := roundf(sin(_t * 6.0) * 3.0)
	var target: Control = step[1]
	_down = step[2]
	_arrow = target != null
	if _arrow:
		var rect := target.get_global_rect()
		_tip = Vector2(rect.get_center().x, (rect.position.y + 20.0 - bob) if _down else (rect.end.y + 2.0 + bob)) - global_position
	_label.text = step[0]
	_label.custom_minimum_size.x = size.x - MARGIN * 2.0
	_label.reset_size()
	var y := _tip.y - ARROW.y - 2.0 - _label.size.y if _down else _tip.y + ARROW.y + 2.0
	_label.position = Vector2(MARGIN, y)
	modulate.a = 0.75 + 0.25 * sin(_t * 4.0)
	queue_redraw()


func _draw() -> void:
	if not _arrow:
		return
	var back := _tip + Vector2(0, -ARROW.y if _down else ARROW.y)
	var pts := PackedVector2Array([_tip, back + Vector2(ARROW.x, 0), back - Vector2(ARROW.x, 0)])
	draw_colored_polygon(pts, OUTLINE)
	var inner := PackedVector2Array([_tip + Vector2(0, -2 if _down else 2), back + Vector2(ARROW.x - 3, 0), back - Vector2(ARROW.x - 3, 0)])
	draw_colored_polygon(inner, COLOR)


func _step() -> Array:
	if GameState.revealed() or GameState.run_over or pile == null or line == null:
		return []
	var segs := GameState.lines[0].segments
	for i in segs.size():
		if segs[i].built:
			continue
		if GameState.scrap < GameState.build_cost(0, i):
			return ["TAP THE SCRAP PILE", pile, true]
		return ["BUILD THE %s STATION" % str(Data.segment_type(segs[i].type_id).name).to_upper(), line.segment_view(i).get_node("Build"), false]
	for i in segs.size():
		if segs[i].stall == SegmentState.Stall.NO_SCRAP:
			return ["OUT OF SCRAP: TAP THE PILE", pile, true]
	var from := 0
	for i in segs.size():
		var m := segs[i].mech
		if m:
			from = i + 1 if segs[i].assembling or m.has_part(segs[i].type_id) else i
	for i in range(from, segs.size()):
		if not segs[i].bar_full():
			return ["TAP STATIONS TO BUILD A MECH", line.segment_view(i), false]
	return ["TAP STATIONS TO BUILD A MECH", null, false]
