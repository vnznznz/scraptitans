class_name LineView
extends Control

const SEG_Y := 14.0
const SEG_X0 := 8.0
const SEG_STEP := 88.0
const BELT_TEX := preload("res://art/line/belt.png")

var line_index := 0

var _segments: Array[SegmentView] = []
var _mechs: Node2D
var _views := {}
var _belt_offset := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, SEG_Y + SegmentView.HEIGHT + 4)
	mouse_filter = MOUSE_FILTER_PASS

	var header := Label.new()
	header.text = "LINE %d" % (line_index + 1)
	header.position = Vector2(8, 2)
	add_child(header)

	for i in _line().segments.size():
		var v := SegmentView.new()
		v.name = "Segment%d" % i
		v.line_index = line_index
		v.seg_index = i
		v.position = Vector2(_seg_x(i), SEG_Y)
		add_child(v)
		_segments.append(v)

	_mechs = Node2D.new()
	add_child(_mechs)


func segment_view(i: int) -> SegmentView:
	return _segments[i]


func _process(delta: float) -> void:
	var belt_y := SEG_Y + SegmentView.BELT_Y
	var belt_time := Data.econ("belt_time")
	var moving := false
	var seen := {}
	var segs := _line().segments
	for i in segs.size():
		var m := segs[i].mech
		if m == null:
			continue
		seen[m.id] = true
		var view: MechView = _views.get(m.id)
		if view == null:
			view = MechView.new()
			_mechs.add_child(view)
			_views[m.id] = view
		view.set_parts(m.parts)
		var x := _center(i)
		if m.arrive_t > 0.0 and i > 0:
			moving = true
			x = lerpf(_center(i - 1), x, 1.0 - m.arrive_t / belt_time)
		view.position = Vector2(x, belt_y)
	for id: int in _views.keys():
		if not seen.has(id):
			_exit(_views[id])
			_views.erase(id)
	if moving:
		_belt_offset = fmod(_belt_offset + delta * GameState.time_scale * SEG_STEP / belt_time, BELT_TEX.get_width())
	queue_redraw()


func _draw() -> void:
	var y := SEG_Y + SegmentView.BELT_Y
	var w := BELT_TEX.get_width()
	var x := -w + _belt_offset
	while x < size.x:
		draw_texture(BELT_TEX, Vector2(x, y))
		x += w


func _exit(view: MechView) -> void:
	var tw := view.create_tween()
	tw.tween_property(view, "position:x", size.x + 16.0, Data.econ("belt_time") / maxf(GameState.time_scale, 1.0))
	tw.tween_callback(view.queue_free)


func _line() -> LineState:
	return GameState.lines[line_index]


func _seg_x(i: int) -> float:
	return SEG_X0 + i * SEG_STEP


func _center(i: int) -> float:
	return _seg_x(i) + SegmentView.WIDTH / 2.0
