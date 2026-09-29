class_name UpgradeMenu
extends Control

const GREY := Color(0.55, 0.55, 0.6)
const SELECTED := Color(1.0, 0.83, 0.3)

var _tab := ""
var _tabs := {}
var _rows: VBoxContainer
var _row_nodes := {}


func _ready() -> void:
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	var group := ButtonGroup.new()
	for tab: Dictionary in Data.upgrades.tabs:
		var b := Button.new()
		b.name = "Tab_" + tab.id
		b.text = tab.name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_color_override("font_pressed_color", SELECTED)
		b.add_theme_color_override("font_hover_pressed_color", SELECTED)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(tab.id))
		grid.add_child(b)
		_tabs[tab.id] = b

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)


func open(tab: String = "") -> void:
	visible = true
	show_tab(tab if tab else (_tab if _tab else str(Data.upgrades.tabs[0].id)))


func close() -> void:
	visible = false


func show_tab(tab: String) -> void:
	_tab = tab
	_tabs[tab].button_pressed = true
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_row_nodes = {}
	for row: Dictionary in Data.upgrade_rows(tab):
		_add_row(row)
	_refresh()


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _add_row(row: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "Row_" + row.id
	panel.mouse_filter = MOUSE_FILTER_PASS
	_rows.add_child(panel)
	var h := HBoxContainer.new()
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var title := Label.new()
	title.text = str(row.name).to_upper()
	v.add_child(title)
	var effect := Label.new()
	effect.modulate = Color(1, 1, 1, 0.7)
	v.add_child(effect)
	var buy := Button.new()
	buy.name = "Buy"
	buy.icon = preload("res://art/ui/credits.png")
	buy.custom_minimum_size = Vector2(104, 44)
	buy.mouse_filter = MOUSE_FILTER_PASS
	buy.pressed.connect(func() -> void: GameState.buy_upgrade(row.id))
	h.add_child(buy)
	_row_nodes[row.id] = [panel, effect, buy]


func _refresh() -> void:
	for id: String in _row_nodes:
		var row := Data.upgrade_row(id)
		var nodes: Array = _row_nodes[id]
		var effect: Label = nodes[1]
		var buy: Button = nodes[2]
		var value := GameState.stat(row.stat)
		var lv := "LV %d/%d  " % [GameState.level(id), int(row.max_level)]
		var maxed := GameState.upgrade_maxed(id)
		if maxed:
			effect.text = lv + _fmt(row, value)
			buy.text = "MAX"
			buy.disabled = true
		else:
			effect.text = lv + "%s > %s" % [_fmt(row, value), _fmt(row, value + float(row.delta))]
			var cost := GameState.upgrade_cost(id)
			buy.text = Fmt.num(cost)
			buy.disabled = GameState.credits < cost
		nodes[0].modulate = Color.WHITE if not buy.disabled else GREY


func _fmt(row: Dictionary, v: float) -> String:
	var unit: String = row.get("unit", "")
	if unit == "%":
		return "%d%%" % roundi(v * 100.0)
	var s := str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))
	return s + unit.to_upper()
