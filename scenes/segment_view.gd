class_name SegmentView
extends Control

const WIDTH := 80.0
const HEIGHT := 89.0
const NAME_H := 25.0
const MACHINE_Y := 25.0
const BELT_Y := 81.0
const BAR_RECT := Rect2(2, 2, 76, 8)
const WORKERS_Y := 42.0
const WORKER_DX := 6.0
const STAT_ICONS := {
	"lifetime": preload("res://art/ui/life.png"),
	"credits_per_sec": preload("res://art/ui/credits.png"),
	"dps": preload("res://art/ui/damage.png"),
}
const PAUSED := Color(0.55, 0.55, 0.6)
const WORKER_TEX := preload("res://art/line/worker.png")
const TOOL_HEAD := Vector2(40, 56)
const BLOCKED_DELAY := 3.0
const WORK_FPS := 11.0

var line_index := 0
var seg_index := 0

var _header: HBoxContainer
var _name: Label
var _machine: TextureRect
var _frames: Array[Texture2D] = []
var _pad: TextureRect
var _build: Button
var _bar: TextureProgressBar
var _stall: TextureRect
var _tap: TapArea
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

	var header := HBoxContainer.new()
	_header = header
	header.name = "Header"
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 1)
	header.position.y = NAME_H - 22
	header.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(header)
	_name = Label.new()
	_name.name = "Name"
	_name.text = str(Data.segment_type(type_id).name).to_upper()
	_name.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	header.add_child(_name)
	var stat := TextureRect.new()
	stat.name = "Stat"
	stat.texture = STAT_ICONS[_stat_key(type_id)]
	stat.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	stat.custom_minimum_size = Vector2(12, 20)
	header.add_child(stat)
	place_header(roundf((WIDTH - header_width()) / 2.0))

	_machine = TextureRect.new()
	for f in 3:
		_frames.append(load("res://art/line/machine_%s_%d.png" % [type_id, f]))
	_machine.texture = _frames[0]
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
	Price.setup(_build, Flyers.Kind.SCRAP)
	_build.size = Vector2(72, 44)
	_build.position = Vector2(4, _pad.position.y + 1.0 - _build.size.y)
	_build.mouse_filter = MOUSE_FILTER_PASS
	_build.set_meta(&"silent", true)
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

	_apply = Button.new()
	_apply.name = "Apply"
	_apply.icon = preload("res://art/ui/up_s.png")
	_apply.add_theme_constant_override("h_separation", 2)
	_apply.position = Vector2(0, -1)
	_apply.size = Vector2(WIDTH, NAME_H + 2)
	_apply.mouse_filter = MOUSE_FILTER_PASS
	Price.setup(_apply, Flyers.Kind.SCRAP, true)
	_apply.set_meta(&"silent", true)
	_apply.pressed.connect(_on_apply)
	add_child(_apply)
	_chunks_seen = _state().chunks
	_assemblies_seen = _state().assemblies
	var n := get_parent()
	while n and not n is ScrollContainer:
		n = n.get_parent()
	_scroll = n


func _process(delta: float) -> void:
	var s := _state()
	var built := s.built
	_machine.visible = built
	_bar.visible = built
	_tap.visible = built
	_pad.visible = not built
	_build.visible = not built
	if not built:
		_apply.visible = false
		_header.visible = true
		var cost := GameState.build_cost(line_index, seg_index)
		Price.show(_build, Fmt.num(cost), GameState.scrap >= cost)
		_stall.visible = false
		return
	_update_apply()
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
	_machine.texture = _frames[1 + int(Time.get_ticks_msec() / 1000.0 * WORK_FPS) % 2] if s.assembling else _frames[0]
	_blocked_t = _blocked_t + delta * GameState.time_scale if s.stall == SegmentState.Stall.BLOCKED else 0.0
	_stall.visible = s.stall == SegmentState.Stall.NO_SCRAP or _blocked_t >= BLOCKED_DELAY
	if _stall.visible:
		_stall.texture = preload("res://art/ui/stall_scrap.png") if s.stall == SegmentState.Stall.NO_SCRAP \
				else preload("res://art/ui/stall_blocked.png")
		_stall.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.4 else 0.3


func _update_workers(s: SegmentState) -> void:
	var slots := int(GameState.stat("worker_slots"))
	var n := GameState.lines[line_index].station_workers(seg_index)
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
		_workers[i].visible = i < n
	if s.chunks != _chunks_seen:
		if n > 0:
			var w := _workers[(s.chunks - 1) % n]
			var tw := w.create_tween()
			tw.tween_property(w, "position:y", WORKERS_Y - 4, 0.08)
			tw.tween_property(w, "position:y", WORKERS_Y, 0.1)
		_bump_t = 0.06
	_chunks_seen = s.chunks


func _update_apply() -> void:
	var fit := GameState.can_apply_tier(line_index, seg_index)
	_apply.visible = fit
	_header.visible = not fit
	if fit:
		var cost := GameState.tier_apply_cost(line_index, seg_index)
		Price.show(_apply, Fmt.num(cost), GameState.scrap >= cost)


func header_width() -> float:
	return _header.get_combined_minimum_size().x


func place_header(x: float) -> void:
	_header.position.x = x
	_header.size = Vector2(header_width(), 20)


static func _stat_key(type_id: String) -> String:
	var tier := Data.tier(type_id, 0)
	for key: String in STAT_ICONS:
		if tier.has(key):
			return key
	return "lifetime"


func _consume(s: SegmentState) -> void:
	(get_parent() as LineView).scrap_bits(position + TOOL_HEAD)
	var head := global_position + TOOL_HEAD
	if _scroll == null or _scroll.get_global_rect().has_point(head):
		Flyers.spend(Flyers.Kind.SCRAP, head, s.scrap_cost())
		Sound.play(StringName("assemble_" + s.type_id))


func _state() -> SegmentState:
	return GameState.lines[line_index].segments[seg_index]


func _on_build() -> void:
	var cost := GameState.build_cost(line_index, seg_index)
	if GameState.build_segment(line_index, seg_index):
		Flyers.pay(Flyers.Kind.SCRAP, _build, cost)
		Sound.play(&"build")


func _on_apply() -> void:
	var cost := GameState.tier_apply_cost(line_index, seg_index) if GameState.can_apply_tier(line_index, seg_index) else 0.0
	if GameState.apply_tier(line_index, seg_index):
		Flyers.pay(Flyers.Kind.SCRAP, _apply, cost)
		Sound.play(&"fit")


func _on_tap(_at: Vector2) -> void:
	if GameState.tap_segment(line_index, seg_index):
		_bump_t = 0.06
		Sound.play(&"station_tap")
