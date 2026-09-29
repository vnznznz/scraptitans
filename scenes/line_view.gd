class_name LineView
extends Control

const SEG_Y := 22.0
const SEG_STEP := 88.0
const BELT_TEX := preload("res://art/line/belt.png")
const PAUSE_TEX := preload("res://art/ui/pause.png")
const PLAY_TEX := preload("res://art/ui/play.png")

var line_index := 0

var _header: Label
var _pause: Button
var _segments: Array[SegmentView] = []
var _mechs: Node2D
var _fx: Node2D
var _views := {}
var _belt_offset := 0.0
var _collapsed := false


func _ready() -> void:
	custom_minimum_size = Vector2(0, SEG_Y + SegmentView.HEIGHT + 4)
	mouse_filter = MOUSE_FILTER_PASS

	_pause = Button.new()
	_pause.name = "Pause"
	_pause.flat = true
	_pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.position = Vector2(2, -6)
	_pause.size = Vector2(40, 32)
	_pause.mouse_filter = MOUSE_FILTER_PASS
	_pause.pressed.connect(GameState.toggle_pause.bind(line_index))
	add_child(_pause)

	_header = Label.new()
	_header.position = Vector2(42, 2)
	add_child(_header)

	_mechs = Node2D.new()
	add_child(_mechs)
	_fx = Node2D.new()
	add_child(_fx)
	_sync_segments()
	resized.connect(_layout)


func collapse() -> void:
	_collapsed = true
	for c in get_children():
		if c is CanvasItem:
			c.visible = false
	queue_redraw()
	for i in _segments.size():
		var p := CPUParticles2D.new()
		p.texture = preload("res://art/fx/debris.png")
		p.position = Vector2(_seg_x(i) + SegmentView.WIDTH / 2.0, SEG_Y + SegmentView.BELT_Y - 30)
		p.amount = 16
		p.one_shot = true
		p.explosiveness = 0.9
		p.lifetime = 0.9
		p.direction = Vector2.UP
		p.spread = 60.0
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 120.0
		p.gravity = Vector2(0, 400)
		p.angular_velocity_min = -300.0
		p.angular_velocity_max = 300.0
		p.emitting = true
		add_child(p)
		p.finished.connect(p.queue_free)


func _sync_segments() -> void:
	for i in range(_segments.size(), _line().segments.size()):
		var v := SegmentView.new()
		v.name = "Segment%d" % i
		v.line_index = line_index
		v.seg_index = i
		add_child(v)
		move_child(v, _mechs.get_index())
		_segments.append(v)
	_layout()


func _layout() -> void:
	for i in _segments.size():
		_segments[i].position = Vector2(_seg_x(i), SEG_Y)


func scrap_bits(pos: Vector2) -> void:
	var bits := _burst(preload("res://art/fx/debris.png"), pos, 10, 0.45)
	bits.scale_amount_max = 1.5
	bits.explosiveness = 0.3
	bits.direction = Vector2.DOWN
	bits.spread = 35.0
	bits.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bits.emission_rect_extents = Vector2(6, 1)
	bits.initial_velocity_min = 20.0
	bits.initial_velocity_max = 50.0
	bits.gravity = Vector2(0, 300)
	bits.angular_velocity_min = -300.0
	bits.angular_velocity_max = 300.0
	var sparks := _burst(preload("res://art/fx/spark.png"), pos + Vector2(0, 10), 6, 0.25)
	sparks.explosiveness = 0.6
	sparks.spread = 180.0
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 70.0
	sparks.gravity = Vector2(0, 200)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 0.8
	sparks.color = Color(1, 0.85, 0.3)


func _burst(tex: Texture2D, pos: Vector2, amount: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.emitting = true
	_fx.add_child(p)
	p.finished.connect(p.queue_free)
	return p


func segment_view(i: int) -> SegmentView:
	return _segments[i]


func _process(delta: float) -> void:
	if _collapsed:
		return
	if _segments.size() != _line().segments.size():
		_sync_segments()
	var paused := _line().paused
	_header.text = "LINE %d%s" % [line_index + 1, "  PAUSED" if paused else ""]
	_header.modulate = Color(1, 0.6, 0.4) if paused else Color.WHITE
	_pause.icon = PLAY_TEX if paused else PAUSE_TEX
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
	if _collapsed:
		var rubble := preload("res://art/line/rubble.png")
		for i in _segments.size():
			draw_texture(rubble, Vector2(_seg_x(i), SEG_Y + SegmentView.BELT_Y - 12))
		return
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
	var n := _segments.size()
	return (size.x - (n - 1) * SEG_STEP - SegmentView.WIDTH) / 2.0 + i * SEG_STEP


func _center(i: int) -> float:
	return _seg_x(i) + SegmentView.WIDTH / 2.0
