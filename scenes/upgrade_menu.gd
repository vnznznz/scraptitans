class_name UpgradeMenu
extends Control

const PANEL_ALPHA := 0.85
const MARGIN := 6
const TIER_STATS := {
	"lifetime": "LIFE %s » %s S",
	"credits_per_sec": "PAY %s » %s/S",
	"dps": "DMG %s » %s",
}

var _scroll: ScrollContainer
var _rows: VBoxContainer
var _row_nodes := {}
var _maxed: PanelContainer
var _maxed_list: Label


class Pips:
	extends Control

	const SIZE := 3.0
	const GAP := 1.0
	const ON := Pal.GOLD
	const OFF := Pal.SLATE_D

	var level := 0
	var max_level := 1

	func set_levels(lv: int, mx: int) -> void:
		if lv == level and mx == max_level:
			return
		level = lv
		max_level = mx
		custom_minimum_size = Vector2(mx * (SIZE + GAP), SIZE)
		queue_redraw()

	func _draw() -> void:
		var y := roundf((size.y - SIZE) / 2.0)
		for i in max_level:
			draw_rect(Rect2(i * (SIZE + GAP), y, SIZE, SIZE), ON if i < level else OFF)


func _ready() -> void:
	visible = false
	add_to_group("upgrade_menu")
	var bg := ColorRect.new()
	bg.color = Color(Pal.INK, 0.8)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.scroll_deadzone = 8
	margin.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows)
	for r: Dictionary in Data.upgrade_list:
		_add_row(r)
	_maxed = PanelContainer.new()
	_maxed.name = "Maxed"
	_maxed.mouse_filter = MOUSE_FILTER_PASS
	_maxed.self_modulate.a = PANEL_ALPHA
	_rows.add_child(_maxed)
	var maxed_box := VBoxContainer.new()
	maxed_box.add_theme_constant_override("separation", 0)
	_maxed.add_child(maxed_box)
	var maxed_title := Label.new()
	maxed_title.text = "MAXED"
	maxed_box.add_child(maxed_title)
	_maxed_list = Label.new()
	_maxed_list.name = "List"
	_maxed_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_maxed_list.modulate = Color(1, 1, 1, 0.6)
	_maxed_list.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	maxed_box.add_child(_maxed_list)


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false


func row(id: String) -> Control:
	return _row_nodes[id][0]


func first_affordable() -> Button:
	for panel in _rows.get_children():
		if not panel.visible or panel == _maxed:
			continue
		var buy: Button = panel.find_child("Buy", true, false)
		if not buy.disabled:
			return buy
	return null


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _add_row(r: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "Row_" + r.id
	panel.mouse_filter = MOUSE_FILTER_PASS
	panel.self_modulate.a = PANEL_ALPHA
	_rows.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var h := HBoxContainer.new()
	box.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var title := Label.new()
	v.add_child(title)
	var effect := Label.new()
	effect.name = "Effect"
	effect.modulate = Color(1, 1, 1, 0.7)
	v.add_child(effect)
	var pips := Pips.new()
	pips.name = "Pips"
	pips.visible = r.get("kind", "") == ""
	pips.size_flags_horizontal = SIZE_SHRINK_BEGIN
	v.add_child(pips)
	var desc := Label.new()
	desc.name = "Desc"
	desc.text = _desc(r).to_upper()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Pal.CYAN)
	desc.visible = false
	box.add_child(desc)
	var info := Button.new()
	info.name = "Info"
	info.icon = preload("res://art/ui/info.png")
	info.flat = true
	info.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.custom_minimum_size = Vector2(32, 44)
	info.mouse_filter = MOUSE_FILTER_PASS
	info.pressed.connect(func() -> void: desc.visible = not desc.visible)
	h.add_child(info)
	var buy := Button.new()
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(104, 44)
	buy.mouse_filter = MOUSE_FILTER_PASS
	buy.set_meta(&"silent", true)
	buy.pressed.connect(_on_buy.bind(r.id))
	Price.setup(buy, Flyers.Kind.CREDITS)
	h.add_child(buy)
	_row_nodes[r.id] = [panel, title, effect, buy, desc, pips]


func _on_buy(id: String) -> void:
	var cost := GameState.upgrade_cost(id)
	if GameState.buy_upgrade(id):
		Flyers.pay(Flyers.Kind.CREDITS, _row_nodes[id][3], cost)
		var kind: String = Data.upgrade_row(id).get("kind", "")
		Sound.play(&"unlock_line" if id == "lines" else &"buy_tier" if kind in ["tier", "final"] else &"buy_upgrade")


func _refresh() -> void:
	var order := []
	var maxed_names := []
	for id: String in _row_nodes:
		var r := Data.upgrade_row(id)
		var nodes: Array = _row_nodes[id]
		var panel: Control = nodes[0]
		var maxed := GameState.upgrade_maxed(id)
		panel.visible = GameState.upgrade_visible(id) and not maxed
		if maxed:
			maxed_names.append(_maxed_name(r))
		if not panel.visible:
			continue
		var cost := GameState.upgrade_cost(id)
		_describe(r, nodes[1], nodes[2], nodes[5])
		if r.get("kind", "") == "tier":
			(nodes[4] as Label).text = _desc(r).to_upper()
		Price.show(nodes[3], Fmt.num(cost), not GameState.upgrade_locked(id) and GameState.credits >= cost)
		order.append([cost, panel.get_index(), panel])
	order.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	for i in order.size():
		if order[i][2].get_index() != i:
			_rows.move_child(order[i][2], i)
	_maxed.visible = not maxed_names.is_empty()
	_maxed_list.text = ", ".join(maxed_names)
	_rows.move_child(_maxed, -1)


func _describe(r: Dictionary, title: Label, effect: Label, pips: Pips) -> void:
	var id: String = r.id
	match r.get("kind", ""):
		"tier":
			var tiers: Array = Data.segment_type(r.type).tiers
			var unlocked := GameState.unlocked_tier(r.type)
			var next: Dictionary = tiers[unlocked + 1]
			title.text = str(next.part).to_upper()
			var plus := "+" if Data.segment_type(r.type).get("optional", false) else ""
			for key: String in TIER_STATS:
				if next.has(key):
					var from := Fmt.num(float(tiers[unlocked][key])) if unlocked >= 0 else "0"
					effect.text = TIER_STATS[key] % [plus + from, plus + Fmt.num(float(next[key]))]
		"final":
			var tiers: Array = Data.segment_type(r.type).tiers
			title.text = str(tiers[-1].part).to_upper()
			effect.text = "NEEDS ALL PARTS" if GameState.upgrade_locked(id) else "ENDS THE WAR"
		_:
			title.text = str(r.name).to_upper()
			var value := GameState.stat(r.stat)
			if r.stat == "lines":
				effect.text = "LINE %d" % (int(value) + 1)
			else:
				effect.text = r.effect % [_fmt(r, value), _fmt(r, value + float(r.delta))]
			pips.set_levels(GameState.level(id), int(r.max_level))


func _maxed_name(r: Dictionary) -> String:
	match r.get("kind", ""):
		"tier", "final":
			return str(Data.segment_type(r.type).tiers[GameState.unlocked_tier(r.type)].part).to_upper()
	return str(r.name).to_upper()


func _desc(r: Dictionary) -> String:
	match r.get("kind", ""):
		"tier":
			var type := Data.segment_type(r.type)
			var unlocked := GameState.unlocked_tier(r.type)
			var part := "%s part. %s " % [type.name, type.desc]
			if unlocked < 0:
				return part + "Unlocks a %s station on every line: build it for %s scrap." % [type.name, Fmt.num(float(type.build_cost))]
			var cost := float(type.tiers[mini(unlocked + 1, type.tiers.size() - 1)].apply_cost)
			return part + "Unlocks it for every line: tap the arrow on each %s station to fit it for %s scrap." % [type.name, Fmt.num(cost)]
		"final":
			return Data.segment_type(r.type).tiers[-1].desc
	return r.desc


func _fmt(r: Dictionary, v: float) -> String:
	var unit: String = r.get("unit", "")
	if unit == "%":
		return "%d%%" % roundi(v * 100.0)
	if r.stat == "payout_cap":
		v = pow(Data.econ("payout_step"), v)
	if unit == "x":
		v = snappedf(v, 1.0 if v >= 10.0 else 0.1)
	var s := str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))
	return "X" + s if unit == "x" else s + unit.to_upper()

