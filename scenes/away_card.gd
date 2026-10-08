class_name AwayCard
extends Control

const VIDEO := preload("res://art/ui/video.png")
const DISCS := 8

var _panel: PanelContainer
var _time: Label
var _rows := {}
var _values := {}
var _collect: Button
var _ad: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(Pal.INK, 0.75)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.custom_minimum_size = Vector2(288, 0)
	_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_panel.grow_horizontal = GROW_DIRECTION_BOTH
	_panel.grow_vertical = GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "WHILE YOU WERE AWAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Pal.ORANGE)
	box.add_child(title)
	_time = Label.new()
	_time.name = "Time"
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	_time.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_time)
	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 2)
	box.add_child(stats)
	for row: Array in [[Flyers.Kind.SCRAP, preload("res://art/ui/scrap.png"), "SCRAP", Pal.STEEL_L], [Flyers.Kind.CREDITS, preload("res://art/ui/credits.png"), "CREDITS", Pal.GOLD]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		stats.add_child(h)
		var icon := TextureRect.new()
		icon.texture = row[1]
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(icon)
		var key := Label.new()
		key.text = row[2]
		key.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(key)
		var value := Label.new()
		value.add_theme_color_override("font_color", row[3])
		h.add_child(value)
		_rows[row[0]] = h
		_values[row[0]] = value
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	box.add_child(buttons)
	_collect = Button.new()
	_collect.name = "Collect"
	_collect.text = "COLLECT"
	_collect.custom_minimum_size = Vector2(0, 44)
	_collect.size_flags_horizontal = SIZE_EXPAND_FILL
	_collect.set_meta(&"silent", true)
	_collect.pressed.connect(_claim.bind(1.0))
	buttons.add_child(_collect)
	_ad = Button.new()
	_ad.name = "Ad"
	_ad.icon = VIDEO
	_ad.text = "X%d" % Data.econ("away_ad_mult")
	_ad.custom_minimum_size = Vector2(80, 44)
	_ad.set_meta(&"silent", true)
	_ad.pressed.connect(_on_ad)
	buttons.add_child(_ad)


func _process(_delta: float) -> void:
	if GameState.away_t <= 0.0 or GameState.run_over:
		visible = false
		return
	_time.text = "THE CREWS WORKED %s%s" % [span(GameState.away_t), " (MAX)" if GameState.away_t >= Data.econ("away_max") else ""]
	for kind: Flyers.Kind in _rows:
		_rows[kind].visible = amount(kind) > 0.0
		_values[kind].text = "+" + Fmt.num(amount(kind))
	_ad.visible = CrazyGames.video_ads
	_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	if not visible:
		_open()


static func span(seconds: float) -> String:
	var minutes := maxi(1, floori(seconds / 60.0))
	if minutes < 60:
		return "%d MIN" % minutes
	return "%d H" % (minutes / 60) if minutes % 60 == 0 else "%d H %d MIN" % [minutes / 60, minutes % 60]


func amount(kind: Flyers.Kind) -> float:
	return GameState.away_scrap if kind == Flyers.Kind.SCRAP else GameState.away_credits


func _open() -> void:
	visible = true
	get_tree().call_group("upgrade_menu", "close")
	Sound.play(&"menu_open")
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.8, 0.8)
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_ad() -> void:
	if await CrazyGames.request_ad("rewarded"):
		_claim(Data.econ("away_ad_mult"))


func _claim(mult: float) -> void:
	if GameState.away_t <= 0.0:
		return
	for kind: Flyers.Kind in _rows:
		if amount(kind) > 0.0:
			Flyers.spawn(kind, _values[kind].get_global_rect().get_center(), amount(kind) * mult, DISCS, true)
	GameState.claim_away(mult)
	visible = false
	Sound.play(&"buy_upgrade")
