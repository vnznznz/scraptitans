class_name UpgradeMenu
extends Control

const GREY := Color(0.55, 0.55, 0.6)

var _scroll: ScrollContainer
var _rows: VBoxContainer
var _row_nodes := {}
var _confirm: Control


func _ready() -> void:
	visible = false
	add_to_group("upgrade_menu")
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 8
	margin.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows)
	for r: Dictionary in Data.upgrade_list:
		_add_row(r)

	_confirm = _build_confirm()


func open() -> void:
	visible = true
	_confirm.visible = false
	_refresh()


func close() -> void:
	visible = false


func row(id: String) -> Control:
	return _row_nodes[id][0]


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _add_row(r: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "Row_" + r.id
	panel.mouse_filter = MOUSE_FILTER_PASS
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
	effect.modulate = Color(1, 1, 1, 0.7)
	v.add_child(effect)
	var desc := Label.new()
	desc.name = "Desc"
	desc.text = _desc(r).to_upper()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
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
	buy.icon = preload("res://art/ui/credits.png")
	buy.custom_minimum_size = Vector2(104, 44)
	buy.mouse_filter = MOUSE_FILTER_PASS
	buy.pressed.connect(_on_buy.bind(r.id))
	h.add_child(buy)
	_row_nodes[r.id] = [panel, title, effect, buy, desc]


func _on_buy(id: String) -> void:
	if Data.upgrade_row(id).get("kind", "") == "final":
		_confirm.set_meta("id", id)
		_confirm.visible = true
		return
	GameState.buy_upgrade(id)


func _refresh() -> void:
	var order := []
	for id: String in _row_nodes:
		var r := Data.upgrade_row(id)
		var nodes: Array = _row_nodes[id]
		var panel: Control = nodes[0]
		var buy: Button = nodes[3]
		panel.visible = GameState.upgrade_visible(id)
		var maxed := GameState.upgrade_maxed(id)
		var cost := GameState.upgrade_cost(id)
		_describe(r, nodes[1], nodes[2])
		if r.get("kind", "") == "tier":
			(nodes[4] as Label).text = _desc(r).to_upper()
		buy.text = "MAX" if maxed else Fmt.num(cost)
		buy.disabled = maxed or GameState.upgrade_locked(id) or GameState.credits < cost
		panel.modulate = Color.WHITE if not buy.disabled else GREY
		order.append([1 if maxed else 0, cost, panel.get_index(), panel])
	order.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	for i in order.size():
		if order[i][3].get_index() != i:
			_rows.move_child(order[i][3], i)


func _describe(r: Dictionary, title: Label, effect: Label) -> void:
	var id: String = r.id
	var maxed := GameState.upgrade_maxed(id)
	match r.get("kind", ""):
		"tier":
			var type := Data.segment_type(r.type)
			var tiers: Array = type.tiers
			var unlocked := GameState.unlocked_tier(r.type)
			var shown := unlocked if maxed else unlocked + 1
			title.text = str(tiers[shown].part).to_upper()
			if unlocked < 0:
				effect.text = "UNLOCKS %s" % str(type.name).to_upper()
			else:
				effect.text = "%s TIER %s" % [str(type.name).to_upper(), "MAX" if maxed else str(shown + 1)]
		"final":
			var tiers: Array = Data.segment_type(r.type).tiers
			title.text = str(tiers[-1].part).to_upper()
			if maxed:
				effect.text = "UNLOCKED"
			elif GameState.upgrade_locked(id):
				effect.text = "NEEDS %s" % str(tiers[-2].part).to_upper()
			else:
				effect.text = "ENDS THE RUN"
		_:
			title.text = str(r.name).to_upper()
			var lv := "LV %d/%d  " % [GameState.level(id), int(r.max_level)]
			var value := GameState.stat(r.stat)
			if maxed:
				effect.text = lv + _fmt(r, value)
			else:
				effect.text = lv + "%s > %s" % [_fmt(r, value), _fmt(r, value + float(r.delta))]


func _desc(r: Dictionary) -> String:
	match r.get("kind", ""):
		"tier":
			var type := Data.segment_type(r.type)
			var first := "The first level adds a %s pad to every line. " % type.name if type.get("optional", false) else ""
			var cost := float(type.tiers[mini(GameState.unlocked_tier(r.type) + 1, type.tiers.size() - 1)].apply_cost)
			var fit := "Then tap the green arrow on each %s station to fit it for %s scrap. " % [type.name, Fmt.num(cost)] if cost > 0.0 else ""
			return "%sUnlocks the next %s part. %s%s" % [first, type.name, fit, type.desc]
		"final":
			return Data.segment_type(r.type).tiers[-1].desc
	return r.desc


func _fmt(r: Dictionary, v: float) -> String:
	var unit: String = r.get("unit", "")
	if unit == "%":
		return "%d%%" % roundi(v * 100.0)
	var s := str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))
	return s + unit.to_upper()


func _build_confirm() -> Control:
	var root := Control.new()
	root.name = "Confirm"
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var label := Label.new()
	label.text = "THIS ENDS\nEVERYTHING.\nUNLOCK?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	box.add_child(label)
	var yes := Button.new()
	yes.name = "Yes"
	yes.text = "UNLOCK"
	yes.custom_minimum_size = Vector2(0, 44)
	yes.pressed.connect(func() -> void:
		GameState.buy_upgrade(root.get_meta("id"))
		root.visible = false)
	box.add_child(yes)
	var no := Button.new()
	no.name = "No"
	no.text = "CANCEL"
	no.custom_minimum_size = Vector2(0, 44)
	no.pressed.connect(func() -> void: root.visible = false)
	box.add_child(no)
	return root
