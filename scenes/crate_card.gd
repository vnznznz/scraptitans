class_name CrateCard
extends Control

const CRATE := [preload("res://art/ui/crate_0.png"), preload("res://art/ui/crate_1.png"), preload("res://art/ui/crate_2.png")]
const TOMORROW := "COME BACK TOMORROW\nFOR A SUPPLY CRATE"
const DISCS := 8
const OPEN_STEP := 0.12

var _panel: PanelContainer
var _crate: TextureRect
var _streak: Label
var _rows := {}
var _values := {}
var _collect: Button


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
	title.text = "SUPPLY CRATE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Pal.ORANGE)
	box.add_child(title)
	_crate = TextureRect.new()
	_crate.name = "Crate"
	_crate.texture = CRATE[0]
	_crate.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_crate.custom_minimum_size = Vector2(0, 32)
	box.add_child(_crate)
	_streak = Label.new()
	_streak.name = "Streak"
	_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	_streak.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_streak)
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
	_collect = Button.new()
	_collect.name = "Collect"
	_collect.text = "COLLECT"
	_collect.custom_minimum_size = Vector2(0, 44)
	_collect.set_meta(&"silent", true)
	_collect.pressed.connect(_claim)
	box.add_child(_collect)


func _process(_delta: float) -> void:
	if not GameState.crate_due or GameState.run_over or GameState.away_t > 0.0:
		visible = false
		return
	var amounts := GameState.crate_amounts()
	for kind: Flyers.Kind in _rows:
		_rows[kind].visible = amounts[kind] > 0.0
		_values[kind].text = "+" + Fmt.num(amounts[kind])
	var streak := GameState.crate_streak_next()
	_streak.text = "DAY %d IN A ROW" % streak
	if streak > 1:
		_streak.text += "   %s" % Fmt.mult(pow(Data.econ("crate_streak_mult"), streak - 1))
	_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	if not visible:
		_open()


func amount(kind: Flyers.Kind) -> float:
	return GameState.crate_amounts()[kind]


func _open() -> void:
	visible = true
	get_tree().call_group("upgrade_menu", "close")
	Sound.play(&"crate_drop")
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.8, 0.8)
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	for k in 3:
		tw.tween_callback(func() -> void:
			_crate.texture = CRATE[k]
			if k == 1:
				Sound.play(&"crate_open")).set_delay(OPEN_STEP if k else 0.0)


func _claim() -> void:
	if not GameState.crate_due:
		return
	for kind: Flyers.Kind in _rows:
		if amount(kind) > 0.0:
			Flyers.spawn(kind, _values[kind].get_global_rect().get_center(), amount(kind), DISCS, true)
	GameState.claim_crate()
	visible = false
	Sound.play(&"buy_upgrade")
