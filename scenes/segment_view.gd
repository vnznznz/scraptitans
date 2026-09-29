class_name SegmentView
extends Control

const WIDTH := 80.0
const HEIGHT := 132.0
const NAME_H := 32.0
const MACHINE_Y := 32.0
const BELT_Y := 88.0
const BAR_RECT := Rect2(2, 2, 76, 8)
const WORKERS_Y := 42.0
const WORKER_DX := 6.0
const ROW_Y := 100.0
const ROW_H := 32.0
const APPLY_W := 24.0
const NO_TIER := Color(0.3, 0.3, 0.33, 0.3)
const TIER_WAITING := Color(1, 1, 1, 0.8)
const PAUSED := Color(0.55, 0.55, 0.6)
const WORKER_TEX := preload("res://art/line/worker.png")
const TOOL_HEAD := Vector2(40, 56)
const BLOCKED_DELAY := 3.0

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
var _apply: Button
var _workers: Array[TextureRect] = []
var _chunks_seen := 0
var _assemblies_seen := 0
var _scroll: ScrollContainer
var _bump_t := 0.0
var _blocked_t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_PASS
	var type_id := _state().type_id

	_name = Label.new()
	_name.position = Vector2(-1, 0)
	_name.size = Vector2(WIDTH + 2, NAME_H)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name.add_theme_constant_override("line_spacing", -4)
	_name.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
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
	_bar.position = BAR_RECT.position
	_bar.size = BAR_RECT.size
	_bar.step = 0.0
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_machine.add_child(_bar)

	_stall = TextureRect.new()
	_stall.name = "Stall"
	_stall.position = Vector2(WIDTH - 14, MACHINE_Y + 12)
	_stall.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stall)

	_tap = TapArea.new()
	_tap.name = "Tap"
	_tap.position = Vector2(0, MACHINE_Y)
	_tap.size = Vector2(WIDTH, BELT_Y + 8 - MACHINE_Y)
	_tap.highlight = _machine
	_tap.tapped.connect(_on_tap)
	add_child(_tap)

	_hire = _row_button("Hire", WORKER_TEX)
	_hire.pressed.connect(_on_hire)

	_hire.position = Vector2(-1, ROW_Y)
	_hire.size = Vector2(WIDTH + 2 - APPLY_W - 2, ROW_H)

	_apply = _row_button("Apply", preload("res://art/ui/up.png"))
	_apply.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply.position = Vector2(WIDTH + 1 - APPLY_W, ROW_Y)
	_apply.size = Vector2(APPLY_W, ROW_H)
	_apply.pressed.connect(func() -> void: GameState.apply_tier(line_index, seg_index))
	_chunks_seen = _state().chunks
	_assemblies_seen = _state().assemblies
	_scroll = get_parent().get_parent().get_parent() as ScrollContainer


func _process(delta: float) -> void:
	var s := _state()
	var built := s.built
	var type := Data.segment_type(s.type_id)
	_name.text = s.tier_data().part if built else type.name
	_machine.visible = built
	_bar.visible = built
	_tap.visible = built
	_hire.visible = built
	_apply.visible = built
	var can_apply := built and GameState.can_apply_tier(line_index, seg_index)
	_apply.disabled = not can_apply or GameState.scrap < GameState.tier_apply_cost(line_index, seg_index)
	_apply.add_theme_color_override("icon_disabled_color", TIER_WAITING if can_apply else NO_TIER)
	_pad.visible = not built
	_build.visible = not built
	if not built:
		var cost := GameState.build_cost(line_index, seg_index)
		_build.text = Fmt.num(cost)
		_build.disabled = GameState.scrap < cost
		_stall.visible = false
		return
	_update_workers(s)
	_machine.modulate = PAUSED if GameState.lines[line_index].paused else Color.WHITE
	if s.assemblies != _assemblies_seen:
		_assemblies_seen = s.assemblies
		_consume(s)
	_bar.max_value = s.bar_size()
	_bar.value = s.work
	_bar.modulate = Color(1.4, 1.4, 1.0) if s.bar_full() else Color.WHITE
	_bump_t = maxf(0.0, _bump_t - delta)
	_machine.position = Vector2(0, MACHINE_Y + (1.0 if _bump_t > 0.0 else 0.0))
	if s.assembling:
		_machine.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)).round()
	_blocked_t = _blocked_t + delta * GameState.time_scale if s.stall == SegmentState.Stall.BLOCKED else 0.0
	_stall.visible = s.stall == SegmentState.Stall.NO_SCRAP or _blocked_t >= BLOCKED_DELAY
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
		var j := int(_workers.size() / 2.0)
		w.position = Vector2(11.0 + j * WORKER_DX if _workers.size() % 2 == 0 else 59.0 - j * WORKER_DX, WORKERS_Y)
		w.flip_h = _workers.size() % 2 == 1
		_machine.add_child(w)
		_machine.move_child(w, 0)
		_workers.append(w)
	for i in _workers.size():
		_workers[i].visible = i < s.workers
	if s.chunks != _chunks_seen and s.workers > 0:
		var w := _workers[(s.chunks - 1) % s.workers]
		var tw := w.create_tween()
		tw.tween_property(w, "position:y", WORKERS_Y - 4, 0.08)
		tw.tween_property(w, "position:y", WORKERS_Y, 0.1)
		_bump_t = 0.06
	_chunks_seen = s.chunks
	var full := s.workers >= slots
	var cost := GameState.worker_cost(line_index, seg_index)
	_hire.text = "MAX" if full else Fmt.num(cost)
	_hire.icon = null if full else WORKER_TEX
	_hire.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if full else HORIZONTAL_ALIGNMENT_LEFT
	_hire.disabled = full or GameState.credits < cost


func _row_button(node_name: String, icon: Texture2D) -> Button:
	var b := Button.new()
	b.name = node_name
	b.icon = icon
	b.add_theme_constant_override("h_separation", 2)
	b.mouse_filter = MOUSE_FILTER_PASS
	add_child(b)
	return b


func _consume(s: SegmentState) -> void:
	(get_parent() as LineView).scrap_bits(position + TOOL_HEAD)
	var head := global_position + TOOL_HEAD
	if _scroll == null or _scroll.get_global_rect().has_point(head):
		Flyers.spend(Flyers.Kind.SCRAP, head, float(s.tier_data().scrap_per_mech))


func _state() -> SegmentState:
	return GameState.lines[line_index].segments[seg_index]


func _on_build() -> void:
	GameState.build_segment(line_index, seg_index)


func _on_hire() -> void:
	GameState.hire_worker(line_index, seg_index)


func _on_tap(_at: Vector2) -> void:
	if GameState.tap_segment(line_index, seg_index):
		_bump_t = 0.06
