class_name IntroGuide
extends Control

enum Place { ABOVE, BELOW, BESIDE }

const COLOR := Pal.YELLOW
const OUTLINE := Pal.INK
const ARROW := Vector2(8, 10)
const MARGIN := 6.0
const PLATE_PAD := 4
const FIELD_TAPS := 3
const FIELD_WAVES := 4
const VETERAN_WARS := 2
const AREA_DIP := 20.0
const BUTTON_DIP := 2.0
const THUMB_HALF := 44.0
const THUMB_ABOVE := 12.0
const LIT := Color(1.5, 1.5, 1.2)
const FRAME_GROW := 2.0
const STORY_COLOR := Pal.CREAM
const STORY_EDGE := Pal.SLATE
const STORY_GAP := 4.0
const PILE := "TAP THE SCRAP PILE"
const STATIONS := "TAP STATIONS TO BUILD A MECH"
const DEFEND := "BUILD MECHS TO DEFEND IT"
const MISSION := "DRONES MARCH ON THE GATE\nBUILD A MECH ARMY\nTO DEFEND YOURSELF"
const STORIES := {STATIONS: "MECHS PUSH THE DRONES BACK", DEFEND: "THE GATE IS UNDER ATTACK"}

var pile: Control
var line: LineView
var battlefield: Battlefield
var upgrades: Control
var menu: UpgradeMenu
var rail: ScrollRail

var _label: Label
var _story: Label
var _tip := Vector2.ZERO
var _down := false
var _arrow := false
var _t := 0.0
var _touched := false
var _touch := Vector2.ZERO
var _lit: CanvasItem
var _frame := Rect2()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Text"
	_label.add_theme_color_override("font_color", COLOR)
	var plate := StyleBoxFlat.new()
	plate.bg_color = OUTLINE
	plate.border_color = COLOR
	plate.set_border_width_all(1)
	plate.content_margin_left = PLATE_PAD
	plate.content_margin_right = PLATE_PAD
	plate.content_margin_top = 0
	plate.content_margin_bottom = 0
	_label.add_theme_stylebox_override("normal", plate)
	add_child(_label)
	_story = Label.new()
	_story.name = "Story"
	_story.add_theme_color_override("font_color", STORY_COLOR)
	_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var story_plate: StyleBoxFlat = plate.duplicate()
	story_plate.border_color = STORY_EDGE
	_story.add_theme_stylebox_override("normal", story_plate)
	add_child(_story)


func text() -> String:
	return _label.text if visible else ""


func story() -> String:
	return _story.text if visible and _story.visible else ""


func _story_for(action: String) -> String:
	if action == PILE and not GameState.lines[0].segments[0].built:
		return MISSION
	return STORIES.get(action, "")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touched = true
		_touch = event.position
	elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		_touched = false


func thumb_zone() -> Rect2:
	if not _touched:
		return Rect2()
	var top := _touch.y - THUMB_ABOVE
	if _touch.x >= size.x / 2.0:
		return Rect2(_touch.x - THUMB_HALF, top, size.x - _touch.x + THUMB_HALF, size.y - top)
	return Rect2(0, top, _touch.x + THUMB_HALF, size.y - top)


func _light(target: Control) -> void:
	var lit: CanvasItem = null
	_frame = Rect2()
	if target is SegmentView:
		lit = (target.get_node("Tap") as TapArea).highlight
	elif target is TapArea:
		lit = (target as TapArea).highlight
	elif target is BaseButton:
		_frame = Rect2(target.global_position - global_position, target.size).grow(FRAME_GROW)
	if _lit != lit and is_instance_valid(_lit):
		_lit.self_modulate = Color.WHITE
	_lit = lit
	if lit:
		lit.self_modulate = Color.WHITE.lerp(LIT, 0.5 + 0.5 * sin(_t * 6.0))


func _process(delta: float) -> void:
	var step := _step()
	visible = not step.is_empty()
	if not visible:
		_light(null)
		return
	_t += delta
	var bob := roundf(sin(_t * 6.0) * 3.0)
	var target: Control = step[1]
	var place: Place = step[2]
	var lit: Control = step[3] if step.size() > 3 else target
	if target and rail and rail.reach(target) != target:
		target = rail.reach(target)
		lit = target
		place = Place.ABOVE if target == rail.pin_button(1) else Place.BELOW
	_light(lit)
	_down = place == Place.ABOVE
	_arrow = target != null
	if _arrow:
		var rect := target.get_global_rect()
		var dip := BUTTON_DIP if target is BaseButton else 0.0 if target is SegmentView else AREA_DIP
		_tip = Vector2(rect.get_center().x, (rect.position.y + dip - bob) if _down else (rect.end.y + 2.0 + bob)) - global_position
	_label.text = step[0]
	_label.reset_size()
	var at := Vector2(_tip.x - _label.size.x / 2.0, _tip.y + ARROW.y + 2.0)
	match place:
		Place.ABOVE:
			at.y = _tip.y - ARROW.y - 2.0 - _label.size.y
		Place.BESIDE:
			at = Vector2(_tip.x - ARROW.x - PLATE_PAD - _label.size.x, _tip.y - bob - 2.0)
	var right := size.x
	if rail and rail.is_visible_in_tree() and not (target and rail.is_ancestor_of(target)):
		right = rail.global_position.x - global_position.x
	var x := clampf(at.x, MARGIN, right - MARGIN - _label.size.x)
	var zone := thumb_zone()
	if zone.intersects(Rect2(Vector2(x, at.y) + global_position, _label.size)):
		var clear := zone.position.x - MARGIN - _label.size.x if zone.position.x > 0.0 else zone.end.x + MARGIN
		if clear >= MARGIN and clear <= right - MARGIN - _label.size.x:
			x = clear
	_label.position = Vector2(x, at.y).round()
	_story.text = _story_for(step[0])
	_story.visible = not _story.text.is_empty()
	if _story.visible:
		_story.reset_size()
		var top := battlefield.get_global_rect().end.y - global_position.y if battlefield else 0.0
		var action_top := _label.position.y + bob
		var y := top + STORY_GAP
		if place == Place.ABOVE and action_top > top:
			y = minf(top + (action_top - top - _story.size.y) / 2.0, action_top - STORY_GAP - _story.size.y)
		_story.position = Vector2((right - _story.size.x) / 2.0, y).round()
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	if _frame.has_area():
		draw_rect(_frame, Color(COLOR, 0.4 + 0.6 * pulse), false, 2.0)
	if not _arrow:
		return
	var back := _tip + Vector2(0, -ARROW.y if _down else ARROW.y)
	var pts := PackedVector2Array([_tip, back + Vector2(ARROW.x, 0), back - Vector2(ARROW.x, 0)])
	draw_colored_polygon(pts, OUTLINE)
	var inner := PackedVector2Array([_tip + Vector2(0, -2 if _down else 2), back + Vector2(ARROW.x - 3, 0), back - Vector2(ARROW.x - 3, 0)])
	draw_colored_polygon(inner, COLOR.lerp(Pal.WHITE, pulse))


func _step() -> Array:
	if GameState.run_over or GameState.prestige >= VETERAN_WARS or pile == null or line == null:
		return []
	if GameState.revealed():
		return _hint()
	var segs := GameState.lines[0].segments
	for i in segs.size():
		if segs[i].built:
			continue
		if GameState.scrap < GameState.build_cost(0, i):
			return [PILE, pile, Place.ABOVE]
		return ["BUILD THE %s STATION" % str(Data.segment_type(segs[i].type_id).name).to_upper(), line.segment_view(i), Place.ABOVE, line.segment_view(i).get_node("Build")]
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
			return [STATIONS, line.segment_view(i), Place.ABOVE]
	return [STATIONS, null, Place.ABOVE]


func _hint() -> Array:
	if GameState.levels.is_empty() and GameState.affordable_upgrades() > 0 and upgrades and menu:
		if not menu.visible:
			return ["UPGRADE AVAILABLE", upgrades, Place.ABOVE]
		var buy := menu.first_affordable()
		if buy:
			return ["BUY IT", buy, Place.BESIDE]
	if GameState.gate_attacked() and not (menu and menu.visible):
		return [DEFEND, line.segment_view(0), Place.ABOVE]
	if GameState.field_taps < FIELD_TAPS and GameState.wave < FIELD_WAVES and GameState.gate_damage <= 0.0 and not GameState.field.is_empty() and battlefield and battlefield.size.y >= Battlefield.HEIGHT and not (menu and menu.visible):
		return ["TAP THE FIELD TO HIT THE WAVE", battlefield.hint_anchor(), Place.ABOVE]
	return []
