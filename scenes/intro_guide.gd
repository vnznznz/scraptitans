class_name IntroGuide
extends Control

enum Place { ABOVE, BELOW, BESIDE }

const COLOR := Pal.YELLOW
const OUTLINE := Pal.INK
const ARROW := Vector2(8, 10)
const MARGIN := 6.0
const PLATE_PAD := 4
const FIELD_TAPS := 3
const AREA_DIP := 20.0
const BUTTON_DIP := 2.0

var pile: Control
var line: LineView
var battlefield: Battlefield
var upgrades: Control
var menu: UpgradeMenu
var rail: ScrollRail

var _label: Label
var _tip := Vector2.ZERO
var _down := false
var _arrow := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Text"
	_label.add_theme_color_override("font_color", COLOR)
	var plate := StyleBoxFlat.new()
	plate.bg_color = OUTLINE
	plate.content_margin_left = PLATE_PAD
	plate.content_margin_right = PLATE_PAD
	plate.content_margin_top = 0
	plate.content_margin_bottom = 0
	_label.add_theme_stylebox_override("normal", plate)
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
	var place: Place = step[2]
	if target and rail and rail.reach(target) != target:
		target = rail.reach(target)
		place = Place.ABOVE if target == rail.pin_button(1) else Place.BELOW
	_down = place == Place.ABOVE
	_arrow = target != null
	if _arrow:
		var rect := target.get_global_rect()
		var dip := BUTTON_DIP if target is BaseButton else AREA_DIP
		_tip = Vector2(rect.get_center().x, (rect.position.y + dip - bob) if _down else (rect.end.y + 2.0 + bob)) - global_position
	_label.text = step[0]
	_label.reset_size()
	var at := Vector2(_tip.x - _label.size.x / 2.0, _tip.y + ARROW.y + 2.0)
	match place:
		Place.ABOVE:
			at.y = _tip.y - ARROW.y - 2.0 - _label.size.y
		Place.BESIDE:
			at = Vector2(_tip.x - ARROW.x - PLATE_PAD - _label.size.x, _tip.y - bob - 2.0)
	_label.position = Vector2(clampf(at.x, MARGIN, size.x - MARGIN - _label.size.x), at.y).round()
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
	if GameState.run_over or pile == null or line == null:
		return []
	if GameState.revealed():
		return _hint()
	var segs := GameState.lines[0].segments
	for i in segs.size():
		if segs[i].built:
			continue
		if GameState.scrap < GameState.build_cost(0, i):
			return ["TAP THE SCRAP PILE", pile, Place.ABOVE]
		return ["BUILD THE %s STATION" % str(Data.segment_type(segs[i].type_id).name).to_upper(), line.segment_view(i).get_node("Build"), Place.BELOW]
	for i in segs.size():
		if segs[i].stall == SegmentState.Stall.NO_SCRAP:
			return ["OUT OF SCRAP: TAP THE PILE", pile, Place.ABOVE]
	var from := 0
	for i in segs.size():
		var m := segs[i].mech
		if m:
			from = i + 1 if segs[i].assembling or m.has_part(segs[i].type_id) else i
	for i in range(from, segs.size()):
		if not segs[i].bar_full():
			return ["TAP STATIONS TO BUILD A MECH", line.segment_view(i), Place.BELOW]
	return ["TAP STATIONS TO BUILD A MECH", null, Place.BELOW]


func _hint() -> Array:
	if GameState.levels.is_empty() and GameState.affordable_upgrades() > 0 and upgrades and menu:
		if not menu.visible:
			return ["UPGRADE AVAILABLE", upgrades, Place.ABOVE]
		var buy := menu.first_affordable()
		if buy:
			return ["BUY IT", buy, Place.BESIDE]
	if GameState.field_taps < FIELD_TAPS and not GameState.field.is_empty() and battlefield and battlefield.size.y >= Battlefield.HEIGHT and not (menu and menu.visible):
		return ["TAP THE FIELD TO HIT THE WAVE", battlefield.hint_anchor(), Place.ABOVE]
	return []
