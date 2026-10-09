class_name UpgradeMenu
extends Control

const BG_ALPHA := 0.92
const MARGIN := 6
const THUMB_W := 4.0
const THUMB_MIN := 20.0
const BANNER_DELAY := 1.0
const BUY_W := 104.0
const AD_W := 30.0
const ROW_GAP := 4.0
const BANNER_GAP := 8
const VIDEO := preload("res://art/ui/video.png")
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
var _thumb: Control
var _banner: ColorRect
var _banner_size := Vector2i.ZERO
var _banner_sent := false
var _open_t := 0.0
var _ad_row: PanelContainer
var _ad_effect: Label
var _ad_watch: Button
var _shown := []


class Pips:
	extends Control

	const SIZE := 4.0
	const GAP := 1.0
	const ON := Pal.GOLD
	const OFF := Pal.SLATE

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
	bg.color = Color(Pal.INK, BG_ALPHA)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	_banner = ColorRect.new()
	_banner.name = "BannerSlot"
	_banner.color = Pal.NAVY
	_banner.visible = false
	column.add_child(_banner)
	_add_ad_row(column)
	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.scroll_deadzone = 8
	column.add_child(_scroll)
	get_window().size_changed.connect(_drop_banner)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows)
	for r: Dictionary in Data.upgrade_list:
		_add_row(r)
	_maxed = PanelContainer.new()
	_maxed.name = "Maxed"
	_maxed.mouse_filter = MOUSE_FILTER_PASS
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
	_thumb = Control.new()
	_thumb.name = "Thumb"
	_thumb.mouse_filter = MOUSE_FILTER_IGNORE
	_thumb.draw.connect(_draw_thumb)
	add_child(_thumb)


func open() -> void:
	visible = true
	_open_t = 0.0
	_banner_sent = false
	_banner_size = _pick_banner() if CrazyGames.banner_due() else Vector2i.ZERO
	_banner.visible = _banner_size != Vector2i.ZERO
	_banner.custom_minimum_size.y = ceilf(_banner_size.y / _css_per_base()) + BANNER_GAP
	_refresh()


func close() -> void:
	visible = false
	CrazyGames.banner_clear()


func banner_slot() -> Control:
	return _banner


func _css_per_base() -> float:
	return Main.window_scale(get_window().size) * CrazyGames.css_per_pixel()


func _pick_banner() -> Vector2i:
	for s in CrazyGames.BANNER_SIZES:
		if s.x / _css_per_base() <= size.x - 2.0 * MARGIN:
			return s
	return Vector2i.ZERO


func banner_css() -> Rect2:
	var window := get_window()
	var scale := Main.window_scale(window.size)
	var bars := (Vector2(window.size) - Vector2(Main.BASE.x, Main.base_height(window.size)) * scale) / 2.0
	var slot := _banner.get_global_rect()
	var at := Vector2(slot.get_center().x, slot.position.y)
	var top := (bars + at * scale) * CrazyGames.css_per_pixel()
	return Rect2(roundf(top.x - _banner_size.x / 2.0), roundf(top.y), _banner_size.x, _banner_size.y)


func _drop_banner() -> void:
	_banner_sent = true
	CrazyGames.banner_clear()


func _add_ad_row(column: VBoxContainer) -> void:
	_ad_row = PanelContainer.new()
	_ad_row.name = "Row_ad_scrap"
	column.add_child(_ad_row)
	var h := HBoxContainer.new()
	_ad_row.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var title := Label.new()
	title.text = "SCRAP X%d" % Data.econ("ad_scrap_mult")
	v.add_child(title)
	_ad_effect = Label.new()
	_ad_effect.name = "Effect"
	_ad_effect.modulate = Color(1, 1, 1, 0.7)
	_ad_effect.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	v.add_child(_ad_effect)
	_ad_watch = Button.new()
	_ad_watch.name = "Watch"
	_ad_watch.icon = VIDEO
	_ad_watch.text = "WATCH"
	_ad_watch.custom_minimum_size = Vector2(104, 44)
	_ad_watch.set_meta(&"silent", true)
	_ad_watch.pressed.connect(_on_ad_scrap)
	h.add_child(_ad_watch)


func _on_ad_scrap() -> void:
	if await CrazyGames.request_ad("rewarded") and GameState.reward_scrap():
		Flyers.spawn(Flyers.Kind.SCRAP, _ad_watch.get_global_rect().get_center(), GameState.scrap_gain_rate * 60.0, 8, true)
		Sound.play(&"buy_upgrade")


func _on_ad_upgrade(id: String) -> void:
	var cost := GameState.upgrade_cost(id)
	if await CrazyGames.request_ad("rewarded") and GameState.reward_upgrade(id):
		Flyers.pay(Flyers.Kind.CREDITS, _row_nodes[id][3], cost)
		Sound.play(&"buy_tier" if Data.upgrade_row(id).get("kind", "") == "tier" else &"buy_upgrade")


func _refresh_ad_row() -> void:
	_ad_row.visible = CrazyGames.video_ads or CrazyGames.adblock
	var minutes := "%d MIN" % (Data.econ("ad_scrap_time") / 60.0)
	_ad_watch.disabled = true
	if CrazyGames.adblock:
		_ad_effect.text = "BLOCKED BY AD BLOCKER"
	elif GameState.scrap_boost_t > 0.0:
		_ad_effect.text = "%s LEFT" % Fmt.clock(GameState.scrap_boost_t)
	elif GameState.ad_cooldown_t > 0.0:
		_ad_effect.text = "NEXT AD IN %s" % Fmt.clock(GameState.ad_cooldown_t)
	else:
		_ad_effect.text = "ALL SCRAP, " + minutes
		_ad_watch.disabled = false


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


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh()
	_open_t += delta
	if _banner.visible and not _banner_sent and _open_t >= BANNER_DELAY:
		_banner_sent = true
		CrazyGames.banner_show(banner_css())


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
	var ad := Button.new()
	ad.name = "Ad"
	ad.icon = VIDEO
	ad.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad.custom_minimum_size = Vector2(AD_W, 44)
	ad.mouse_filter = MOUSE_FILTER_PASS
	ad.set_meta(&"silent", true)
	ad.visible = false
	ad.pressed.connect(_on_ad_upgrade.bind(r.id))
	h.add_child(ad)
	var buy := Button.new()
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(BUY_W, 44)
	buy.mouse_filter = MOUSE_FILTER_PASS
	buy.set_meta(&"silent", true)
	buy.pressed.connect(_on_buy.bind(r.id))
	Price.setup(buy, Flyers.Kind.CREDITS)
	h.add_child(buy)
	_row_nodes[r.id] = [panel, title, effect, buy, desc, pips, ad]


func _on_buy(id: String) -> void:
	var cost := GameState.upgrade_cost(id)
	if GameState.buy_upgrade(id):
		Flyers.pay(Flyers.Kind.CREDITS, _row_nodes[id][3], cost)
		var kind: String = Data.upgrade_row(id).get("kind", "")
		Sound.play(&"unlock_line" if id == "lines" else &"buy_tier" if kind in ["tier", "final"] else &"buy_upgrade")


func _refresh() -> void:
	_refresh_ad_row()
	var offers: Array[String] = []
	if CrazyGames.video_ads:
		offers = GameState.ad_offers()
	_thumb.queue_redraw()
	var affordable := []
	for id: String in _row_nodes:
		affordable.append(GameState.credits >= GameState.upgrade_cost(id))
	var state := [GameState.levels.hash(), GameState.prestige, offers, affordable]
	if state == _shown:
		return
	_shown = state
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
		var offered := id in offers
		(nodes[6] as Button).visible = offered
		(nodes[3] as Button).custom_minimum_size.x = BUY_W - AD_W - ROW_GAP if offered else BUY_W
		order.append([cost, Data.upgrade_list.find(r), panel])
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


func track() -> Rect2:
	return Rect2(size.x - MARGIN + 1.0, _scroll.global_position.y - global_position.y, THUMB_W, _scroll.size.y)


func thumb() -> Rect2:
	var bar := _scroll.get_v_scroll_bar()
	var span := bar.max_value - bar.page
	if span <= 0.0:
		return Rect2()
	var groove := track()
	var h := maxf(THUMB_MIN, roundf(groove.size.y * bar.page / bar.max_value))
	var y := groove.position.y + roundf((groove.size.y - h) * _scroll.scroll_vertical / span)
	return Rect2(groove.position.x, y, THUMB_W, h)


func _draw_thumb() -> void:
	var grabber := thumb()
	if not grabber.has_area():
		return
	var groove := track()
	_thumb.draw_rect(groove, Pal.INK)
	_thumb.draw_rect(groove.grow_individual(-1, 0, -1, 0), Pal.NAVY)
	_thumb.draw_rect(grabber, Pal.INK)
	_thumb.draw_rect(grabber.grow(-1), Pal.SLATE)
	_thumb.draw_rect(Rect2(grabber.position + Vector2.ONE, Vector2(THUMB_W - 2.0, 1)), Pal.STEEL)


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
					var scale := 1.0 if key == "lifetime" else GameState.war_scale()
					var from := Fmt.num(float(tiers[unlocked][key]) * scale) if unlocked >= 0 else "0"
					effect.text = TIER_STATS[key] % [plus + from, plus + Fmt.num(float(next[key]) * scale)]
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
		"tier":
			return str(Data.tier(r.type, GameState.top_tier(r.type)).part).to_upper()
		"final":
			return str(Data.segment_type(r.type).tiers[-1].part).to_upper()
	return str(r.name).to_upper()


func _desc(r: Dictionary) -> String:
	match r.get("kind", ""):
		"tier":
			var type := Data.segment_type(r.type)
			var unlocked := GameState.unlocked_tier(r.type)
			var part := "%s part. %s " % [type.name, type.desc]
			if unlocked < 0:
				return part + "Unlocks a %s station on every line: build it for %s scrap." % [type.name, Fmt.num(float(type.build_cost) * GameState.war_scale())]
			var cost := float(type.tiers[mini(unlocked + 1, type.tiers.size() - 1)].apply_cost) * GameState.war_scale()
			return part + "Unlocks it for every line: tap the arrow on each %s station to fit it for %s scrap." % [type.name, Fmt.num(cost)]
		"final":
			return Data.segment_type(r.type).tiers[-1].desc
	return r.desc


func _fmt(r: Dictionary, v: float) -> String:
	var unit: String = r.get("unit", "")
	if r.stat == "yard_chunk":
		return Fmt.short(v * GameState.pile_scale())
	if r.stat == "kill_scrap":
		return Fmt.short(v * GameState.war_scale())
	if unit == "%":
		return "%d%%" % roundi(v * 100.0)
	if r.stat == "payout_cap":
		v = pow(Data.econ("payout_step"), v)
	if unit == "x":
		v = snappedf(v, 1.0 if v >= 10.0 else 0.1)
	var s := str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))
	return "X" + s if unit == "x" else s + unit.to_upper()

