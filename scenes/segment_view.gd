class_name SegmentView
extends Control

const WIDTH := 80.0
const HEIGHT := 174.0
const NAME_H := 36.0
const MACHINE_Y := 38.0
const BELT_Y := 94.0
const WORKERS_Y := 120.0
const WORKER_DX := 10.0
const HIRE_Y := 138.0
const WORKER_TEX := preload("res://art/line/worker.png")

var line_index := 0
var seg_index := 0

var _name: Label
var _machine: TextureRect
var _pad: TextureRect
var _build: Button
var _bar: TextureProgressBar
var _stall: TextureRect
var _tap: TapArea
var _hire: Button
var _slow: ReferenceRect
var _workers: Array[TextureRect] = []
var _chunks_seen := 0
var _bump_t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_PASS
	var type_id := _state().type_id

	_name = Label.new()
	_name.position = Vector2(-4, 0)
	_name.size = Vector2(WIDTH + 8, NAME_H)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name.add_theme_constant_override("line_spacing", -4)
	add_child(_name)

	_machine = TextureRect.new()
	_machine.texture = load("res://art/line/machine_%s.png" % type_id)
	_machine.position = Vector2(0, MACHINE_Y)
	_machine.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_machine)

	_pad = TextureRect.new()
	_pad.texture = preload("res://art/line/pad.png")
	_pad.position = Vector2(8, BELT_Y - 8)
	_pad.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_pad)

	_build = Button.new()
	_build.name = "Build"
	_build.icon = preload("res://art/ui/scrap.png")
	_build.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build.position = Vector2(4, MACHINE_Y + 4)
	_build.size = Vector2(72, 44)
	_build.mouse_filter = MOUSE_FILTER_PASS
	_build.pressed.connect(_on_build)
	add_child(_build)

	_bar = TextureProgressBar.new()
	_bar.texture_under = preload("res://art/ui/bar_under.png")
	_bar.texture_progress = preload("res://art/ui/bar_fill.png")
	_bar.nine_patch_stretch = true
	_bar.stretch_margin_left = 2
	_bar.stretch_margin_top = 2
	_bar.stretch_margin_right = 2
	_bar.stretch_margin_bottom = 2
	_bar.position = Vector2(4, BELT_Y + 14)
	_bar.size = Vector2(72, 8)
	_bar.step = 0.0
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bar)

	_stall = TextureRect.new()
	_stall.name = "Stall"
	_stall.position = Vector2(WIDTH - 14, MACHINE_Y + 12)
	_stall.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stall)

	_slow = ReferenceRect.new()
	_slow.name = "Bottleneck"
	_slow.editor_only = false
	_slow.border_color = Color(1.0, 0.55, 0.15)
	_slow.border_width = 2.0
	_slow.position = Vector2(-2, MACHINE_Y - 2)
	_slow.size = Vector2(WIDTH + 4, BELT_Y + 24 - MACHINE_Y)
	_slow.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_slow)

	_tap = TapArea.new()
	_tap.name = "Tap"
	_tap.position = Vector2(0, MACHINE_Y)
	_tap.size = Vector2(WIDTH, BELT_Y + 22 - MACHINE_Y)
	_tap.tapped.connect(_on_tap)
	add_child(_tap)

	_hire = Button.new()
	_hire.name = "Hire"
	_hire.icon = preload("res://art/ui/worker.png")
	_hire.position = Vector2(4, HIRE_Y)
	_hire.size = Vector2(72, 34)
	_hire.mouse_filter = MOUSE_FILTER_PASS
	_hire.pressed.connect(_on_hire)
	add_child(_hire)
	_chunks_seen = _state().chunks


func _process(delta: float) -> void:
	var s := _state()
	var built := s.built
	var type := Data.segment_type(s.type_id)
	_name.text = s.tier_data().part if built else type.name
	_machine.visible = built
	_bar.visible = built
	_tap.visible = built
	_hire.visible = built
	_slow.visible = false
	_pad.visible = not built
	_build.visible = not built
	if not built:
		var cost := GameState.build_cost(line_index, seg_index)
		_build.text = Fmt.num(cost)
		_build.disabled = GameState.scrap < cost
		_stall.visible = false
		return
	_update_workers(s)
	_slow.visible = GameState.bottlenecks(line_index).has(seg_index)
	_slow.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
	_bar.max_value = s.bar_size()
	_bar.value = s.work
	_bar.modulate = Color(1.4, 1.4, 1.0) if s.bar_full() else Color.WHITE
	_bump_t = maxf(0.0, _bump_t - delta)
	_machine.position = Vector2(0, MACHINE_Y + (1.0 if _bump_t > 0.0 else 0.0))
	if s.assembling:
		_machine.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)).round()
	_stall.visible = s.stall != SegmentState.Stall.NONE
	if _stall.visible:
		_stall.texture = preload("res://art/ui/stall_scrap.png") if s.stall == SegmentState.Stall.NO_SCRAP \
				else preload("res://art/ui/stall_blocked.png")
		_stall.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.4 else 0.3


func _update_workers(s: SegmentState) -> void:
	var slots := s.worker_slots()
	while _workers.size() < slots:
		var w := TextureRect.new()
		w.texture = WORKER_TEX
		w.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(w)
		_workers.append(w)
	var x0 := (WIDTH - slots * WORKER_DX) / 2.0
	for i in _workers.size():
		var w := _workers[i]
		w.visible = i < slots
		w.modulate = Color.WHITE if i < s.workers else Color(0.4, 0.4, 0.45, 0.5)
		w.position.x = x0 + i * WORKER_DX
		if w.position.y == 0.0:
			w.position.y = WORKERS_Y
	if s.chunks != _chunks_seen and s.workers > 0:
		var w := _workers[(s.chunks - 1) % s.workers]
		var tw := w.create_tween()
		tw.tween_property(w, "position:y", WORKERS_Y - 4, 0.08)
		tw.tween_property(w, "position:y", WORKERS_Y, 0.1)
		_bump_t = 0.06
	_chunks_seen = s.chunks
	var maxed := s.workers >= slots
	var cost := GameState.worker_cost(line_index, seg_index)
	_hire.text = "MAX" if maxed else Fmt.num(cost)
	_hire.disabled = maxed or GameState.credits < cost


func _state() -> SegmentState:
	return GameState.lines[line_index].segments[seg_index]


func _on_build() -> void:
	GameState.build_segment(line_index, seg_index)


func _on_hire() -> void:
	GameState.hire_worker(line_index, seg_index)


func _on_tap(_at: Vector2) -> void:
	if GameState.tap_segment(line_index, seg_index):
		_bump_t = 0.06
