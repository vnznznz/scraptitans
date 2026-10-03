class_name LineView
extends Control

const SEG_STEP := 84.0
const PAUSE_W := 20.0
const STRIP_PAD := 2.0
const CREW_H := 26.0
const HIRE_W := 120.0
const HEADER_GAP := 4.0
const L_FILL := Pal.SLATE_D
const L_LIGHT := Pal.SLATE
const L_EDGE := Pal.INK
const METER := Rect2(6, 26, 8, 44)
const METER_BG := Color(Pal.INK, 0.6)
const USAGE_COLOR := Pal.STEEL_L
const BELT_TEX := preload("res://art/line/belt.png")
const PAUSE_TEX := preload("res://art/ui/pause.png")
const PLAY_TEX := preload("res://art/ui/play.png")
const TAG := Vector2(16, 20)
const TAG_GAP := 4.0

var line_index := 0

var _pause: Button
var _hire: Button
var _crew: Label
var _tag: Label
var _tagged := false
var _pause_icon: TextureRect
var _usage: ColorRect
var _strip_k := 0.0
var _bar_k := 0.0
var _top := 0.0
var _segments: Array[SegmentView] = []
var _mechs: Node2D
var _fx: Node2D
var _views := {}
var _states := {}
var _belt_offset := 0.0
var _collapsed := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

	_pause = Button.new()
	_pause.name = "Pause"
	_pause.size = Vector2(PAUSE_W, SegmentView.BELT_Y + 8.0)
	_pause.flat = true
	_pause.mouse_filter = MOUSE_FILTER_PASS
	_pause.set_meta(&"silent", true)
	_pause.pressed.connect(_on_pause)
	add_child(_pause)
	var scrap_icon := TextureRect.new()
	scrap_icon.texture = preload("res://art/ui/scrap.png")
	scrap_icon.position = Vector2(STRIP_PAD, 6)
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
	_pause_icon.position = Vector2(STRIP_PAD, _pause.size.y - 22)
	_pause_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_pause.add_child(_pause_icon)

	_tag = Label.new()
	_tag.name = "Tag"
	_tag.text = str(line_index + 1)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag.add_theme_color_override("font_color", Pal.INK)
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Pal.line(line_index)
	tag_style.border_color = Pal.INK
	tag_style.set_border_width_all(1)
	_tag.add_theme_stylebox_override("normal", tag_style)
	_tag.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_tag)
	_crew = Label.new()
	_crew.name = "Crew"
	_crew.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	_crew.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crew.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_crew)
	_hire = Button.new()
	_hire.name = "Hire"
	_hire.icon = preload("res://art/line/worker.png")
	_hire.mouse_filter = MOUSE_FILTER_PASS
	Price.setup(_hire, Flyers.Kind.CREDITS, true)
	_hire.set_meta(&"silent", true)
	_hire.pressed.connect(_on_hire)
	add_child(_hire)

	_mechs = Node2D.new()
	add_child(_mechs)
	_fx = Node2D.new()
	add_child(_fx)
	_strip_k = Reveal.step(0.0, GameState.stalled_once, INF)
	_bar_k = Reveal.step(0.0, GameState.shown("crew"), INF)
	_tagged = GameState.lines.size() > 1
	_sync_segments()
	resized.connect(_layout)


func collapse() -> void:
	_collapsed = true
	for c in get_children():
		if c is CanvasItem:
			c.visible = false
	queue_redraw()
	for i in _segments.size():
		var at := Vector2(_seg_x(i) + SegmentView.WIDTH / 2.0, _top + SegmentView.BELT_Y - 30)
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
	_top = roundf(CREW_H * Reveal.eased(_bar_k))
	var bar_y := _top - CREW_H
	var right := size.x
	for i in range(_segments.size() - 1, -1, -1):
		var seg := _segments[i]
		seg.position = Vector2(_seg_x(i), _top)
		var w := seg.header_width()
		var x := minf(roundf(_seg_x(i) + (SegmentView.WIDTH - w) / 2.0), right - w)
		seg.place_header(x - _seg_x(i))
		right = x - HEADER_GAP
	custom_minimum_size = Vector2(0, _top + SegmentView.BELT_Y + 8.0)
	_pause.visible = _strip_k > 0.0
	_pause.position = Vector2(_left() - PAUSE_W, _top)
	_pause.size = Vector2(PAUSE_W, SegmentView.BELT_Y + 8.0)
	_tag.position = Vector2(_left() + TAG_GAP, bar_y + 3.0)
	_tag.size = TAG
	var crew_x := _left() + 6.0 + (TAG.x + TAG_GAP if _tagged else 0.0)
	_crew.position = Vector2(crew_x, bar_y)
	_crew.size = Vector2(maxf(size.x - HIRE_W - crew_x, 0.0), CREW_H - 1.0)
	_hire.position = Vector2(size.x - HIRE_W, bar_y + 1.0)
	_hire.size = Vector2(HIRE_W, CREW_H - 1.0)
	clip_contents = Reveal.moving(_strip_k) or Reveal.moving(_bar_k)
	queue_redraw()


func hire_button() -> Button:
	return _hire


func _on_hire() -> void:
	var cost := GameState.worker_cost(line_index)
	if GameState.hire_worker(line_index):
		Flyers.pay(Flyers.Kind.CREDITS, _hire, cost)
		Sound.play(&"hire")


func _on_pause() -> void:
	GameState.toggle_pause(line_index)
	Sound.play(&"pause" if _line().paused else &"resume")


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
	var strip := Reveal.step(_strip_k, GameState.stalled_once, delta)
	var bar := Reveal.step(_bar_k, GameState.shown("crew"), delta)
	var tagged := GameState.lines.size() > 1
	if strip != _strip_k or bar != _bar_k or tagged != _tagged:
		_strip_k = strip
		_bar_k = bar
		_tagged = tagged
		_layout()
	var line := _line()
	var slots := line.worker_slots()
	_crew.text = "CREW %d/%d" % [line.workers, slots]
	_crew.visible = _bar_k > 0.0
	_tag.visible = _bar_k > 0.0 and _tagged
	_crew.modulate.a = 1.0 if slots > 0 else 0.5
	_hire.visible = _bar_k > 0.0 and line.workers < slots
	if _hire.visible:
		var cost := GameState.worker_cost(line_index)
		Price.show(_hire, Fmt.num(cost), GameState.credits >= cost)
	var paused := line.paused
	_pause_icon.texture = PLAY_TEX if paused else PAUSE_TEX
	var share := clampf(_line().scrap_used_rate / maxf(GameState.scrap_gain_rate, 1.0), 0.0, 1.0)
	var h := roundf(METER.size.y * share)
	_usage.position = Vector2(METER.position.x, METER.end.y - h)
	_usage.size = Vector2(METER.size.x, h)
	_usage.color = Hud.STARVED if _line().starved() else (USAGE_COLOR * Color(1, 1, 1, 0.5) if paused else USAGE_COLOR)
	var belt_y := _top + SegmentView.BELT_Y
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
			_states[m.id] = m
		view.set_parts(m.parts)
		var x := _center(i)
		if m.arrive_t > 0.0 and i > 0:
			moving = true
			x = lerpf(_center(i - 1), x, 1.0 - m.arrive_t / belt_time)
		view.position = Vector2(x, belt_y)
	for id: int in _views.keys():
		if not seen.has(id):
			_views[id].set_parts(_states[id].parts)
			_exit(_views[id])
			_views.erase(id)
			_states.erase(id)
	if moving:
		_belt_offset = fmod(_belt_offset + delta * GameState.time_scale * SEG_STEP / belt_time, BELT_TEX.get_width())
	queue_redraw()


func _draw() -> void:
	if _collapsed:
		var rubble := preload("res://art/line/rubble.png")
		for i in _segments.size():
			draw_texture(rubble, Vector2(_seg_x(i), _top + SegmentView.BELT_Y - 12))
		return
	var y := _top + SegmentView.BELT_Y
	var w := BELT_TEX.get_width()
	var x := _left() - w + _belt_offset
	while x < size.x:
		draw_texture(BELT_TEX, Vector2(x, y))
		x += w
	_draw_frame()


func _draw_frame() -> void:
	var bottom := _top + SegmentView.BELT_Y + 8.0
	if _bar_k > 0.0:
		draw_bar(self, size.x, _left(), _top - CREW_H)
	if _strip_k > 0.0:
		var x := _left() - PAUSE_W
		draw_rect(Rect2(x, 0, PAUSE_W, bottom), L_FILL)
		draw_rect(Rect2(x, 0, 1, bottom), L_LIGHT)
		draw_rect(Rect2(x + PAUSE_W - 1.0, _top, 1, bottom - _top), L_EDGE)
		draw_rect(Rect2(x, bottom - 1.0, PAUSE_W, 1), L_EDGE)
		if _bar_k <= 0.0:
			draw_rect(Rect2(x, 0, PAUSE_W, 1), L_LIGHT)


static func draw_bar(ci: CanvasItem, width: float, left: float, y := 0.0) -> void:
	ci.draw_rect(Rect2(0, y, width, CREW_H), L_FILL)
	ci.draw_rect(Rect2(0, y, width, 1), L_LIGHT)
	ci.draw_rect(Rect2(left, y + CREW_H - 1.0, width - left, 1), L_EDGE)


func _exit(view: MechView) -> void:
	if Sound.visible_share(self) > 0.5:
		Sound.play(&"mech_exit")
	var tw := view.create_tween()
	tw.tween_property(view, "position:x", size.x + 16.0, Data.econ("belt_time") / maxf(GameState.time_scale, 1.0))
	tw.tween_callback(view.queue_free)


func _line() -> LineState:
	return GameState.lines[line_index]


func _left() -> float:
	return roundf(PAUSE_W * Reveal.eased(_strip_k))


func _seg_x(i: int) -> float:
	var n := _segments.size()
	var room := size.x - _left() - SegmentView.WIDTH
	var step := minf(SEG_STEP, floorf(room / (n - 1))) if n > 1 else SEG_STEP
	return _left() + roundf((room - (n - 1) * step) / 2.0) + i * step


func _center(i: int) -> float:
	return _seg_x(i) + SegmentView.WIDTH / 2.0
