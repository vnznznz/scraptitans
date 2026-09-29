class_name LineView
extends Control

const SEG_Y := 0.0
const SEG_STEP := 84.0
const PAUSE_W := 24.0
const METER := Rect2(8, 26, 8, 44)
const METER_BG := Color(Pal.INK, 0.6)
const USAGE_COLOR := Pal.STEEL_L
const BELT_TEX := preload("res://art/line/belt.png")
const PAUSE_TEX := preload("res://art/ui/pause.png")
const PLAY_TEX := preload("res://art/ui/play.png")

var line_index := 0

var _pause: Button
var _pause_icon: TextureRect
var _usage: ColorRect
var _strip := false
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
	_pause.position = Vector2(0, SEG_Y)
	_pause.size = Vector2(PAUSE_W, SegmentView.BELT_Y + 8.0)
	_pause.mouse_filter = MOUSE_FILTER_PASS
	_pause.pressed.connect(GameState.toggle_pause.bind(line_index))
	add_child(_pause)
	var scrap_icon := TextureRect.new()
	scrap_icon.texture = preload("res://art/ui/scrap.png")
	scrap_icon.position = Vector2(4, 6)
	scrap_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_pause.add_child(scrap_icon)
	var meter := ColorRect.new()
	meter.color = METER_BG
	meter.position = METER.position
	meter.size = METER.size
	meter.mouse_filter = MOUSE_FILTER_IGNORE
	_pause.add_child(meter)
	_usage = ColorRect.new()
	_usage.name = "Usage"
	_usage.mouse_filter = MOUSE_FILTER_IGNORE
	_pause.add_child(_usage)
	_pause_icon = TextureRect.new()
	_pause_icon.position = Vector2(4, _pause.size.y - 22)
	_pause_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_pause.add_child(_pause_icon)

	_mechs = Node2D.new()
	add_child(_mechs)
	_fx = Node2D.new()
	add_child(_fx)
	_strip = GameState.stalled_once
	_pause.visible = _strip
	_sync_segments()
	resized.connect(_layout)


func collapse() -> void:
	_collapsed = true
	for c in get_children():
		if c is CanvasItem:
			c.visible = false
	queue_redraw()
	for i in _segments.size():
		var at := Vector2(_seg_x(i) + SegmentView.WIDTH / 2.0, SEG_Y + SegmentView.BELT_Y - 30)
		Fx.explosion(self, at + Vector2(randf_range(-16, 16), randf_range(-10, 10)), true, randf_range(0.4, 0.7))
		Fx.debris(self, at, 12)
		Fx.debris(self, at, 6, true)


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
	sparks.color = Pal.YELLOW


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
	if _strip != GameState.stalled_once:
		_strip = GameState.stalled_once
		_pause.visible = _strip
		_layout()
		queue_redraw()
	var paused := _line().paused
	_pause_icon.texture = PLAY_TEX if paused else PAUSE_TEX
	var share := clampf(_line().scrap_used_rate / maxf(GameState.scrap_gain_rate, 1.0), 0.0, 1.0)
	var h := roundf(METER.size.y * share)
	_usage.position = Vector2(METER.position.x, METER.end.y - h)
	_usage.size = Vector2(METER.size.x, h)
	_usage.color = Hud.STARVED if _line().starved() else (USAGE_COLOR * Color(1, 1, 1, 0.5) if paused else USAGE_COLOR)
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
	var x := _left() - w + _belt_offset
	while x < size.x:
		draw_texture(BELT_TEX, Vector2(x, y))
		x += w


func _exit(view: MechView) -> void:
	var tw := view.create_tween()
	tw.tween_property(view, "position:x", size.x + 16.0, Data.econ("belt_time") / maxf(GameState.time_scale, 1.0))
	tw.tween_callback(view.queue_free)


func _line() -> LineState:
	return GameState.lines[line_index]


func _left() -> float:
	return PAUSE_W if _strip else 0.0


func _seg_x(i: int) -> float:
	var n := _segments.size()
	return _left() + (size.x - _left() - (n - 1) * SEG_STEP - SegmentView.WIDTH) / 2.0 + i * SEG_STEP


func _center(i: int) -> float:
	return _seg_x(i) + SegmentView.WIDTH / 2.0
