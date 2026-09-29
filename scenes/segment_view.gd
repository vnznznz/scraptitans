class_name SegmentView
extends Control

const WIDTH := 80.0
const HEIGHT := 96.0
const MACHINE_Y := 10.0
const BELT_Y := 66.0

var line_index := 0
var seg_index := 0

var _name: Label
var _machine: TextureRect
var _pad: TextureRect
var _build: Button
var _bar: TextureProgressBar
var _stall: TextureRect
var _tap: TapArea
var _bump_t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_PASS
	var type_id := _state().type_id

	_name = Label.new()
	_name.position = Vector2(0, 0)
	_name.size = Vector2(WIDTH, 10)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_build.position = Vector2(4, 14)
	_build.size = Vector2(72, 40)
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

	_tap = TapArea.new()
	_tap.name = "Tap"
	_tap.position = Vector2(0, MACHINE_Y)
	_tap.size = Vector2(WIDTH, HEIGHT - MACHINE_Y)
	_tap.tapped.connect(_on_tap)
	add_child(_tap)


func _process(delta: float) -> void:
	var s := _state()
	var built := s.built
	var type := Data.segment_type(s.type_id)
	_name.text = s.tier_data().part if built else type.name
	_machine.visible = built
	_bar.visible = built
	_tap.visible = built
	_pad.visible = not built
	_build.visible = not built
	if not built:
		var cost := GameState.build_cost(line_index, seg_index)
		_build.text = "BUILD %s" % Fmt.num(cost)
		_build.disabled = GameState.scrap < cost
		_stall.visible = false
		return
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


func _state() -> SegmentState:
	return GameState.lines[line_index].segments[seg_index]


func _on_build() -> void:
	GameState.build_segment(line_index, seg_index)


func _on_tap(_at: Vector2) -> void:
	if GameState.tap_segment(line_index, seg_index):
		_bump_t = 0.06
