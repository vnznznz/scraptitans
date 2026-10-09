class_name GateLost
extends Control

const SHOW_DELAY := 1.6

var _dim: ColorRect
var _card: PanelContainer
var _again: Button
var _next: Label
var _values: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(Pal.INK, 0.0)
	_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_dim)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.custom_minimum_size = Vector2(288, 0)
	_card.set_anchors_and_offsets_preset(PRESET_CENTER)
	_card.grow_horizontal = GROW_DIRECTION_BOTH
	_card.grow_vertical = GROW_DIRECTION_BOTH
	_card.visible = false
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_card.add_child(box)
	var title := Label.new()
	title.text = "THE GATE HAS FALLEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Pal.RED)
	box.add_child(title)
	var sub := Label.new()
	sub.name = "Sub"
	sub.text = "NO MECH HELD THE FIELD"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)
	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 2)
	box.add_child(stats)
	for row: Array in [[preload("res://art/ui/life.png"), "TIME", Pal.STEEL_L], [preload("res://art/ui/mech.png"), "MECHS", Pal.CYAN]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		stats.add_child(h)
		var icon := TextureRect.new()
		icon.texture = row[0]
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(icon)
		var key := Label.new()
		key.text = row[1]
		key.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(key)
		var value := Label.new()
		value.add_theme_color_override("font_color", row[2])
		h.add_child(value)
		_values.append(value)
	_next = Label.new()
	_next.name = "Next"
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	_next.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_next)
	_again = Button.new()
	_again.name = "TryAgain"
	_again.text = "TRY AGAIN"
	_again.theme_type_variation = &"LitButton"
	_again.custom_minimum_size = Vector2(0, 44)
	_again.pressed.connect(_try_again)
	box.add_child(_again)

	GameState.gate_fell.connect(_on_fell)
	if GameState.lost:
		_show()


func card_visible() -> bool:
	return _card.visible


func _on_fell() -> void:
	visible = true
	get_tree().call_group("upgrade_menu", "close")
	await get_tree().create_timer(SHOW_DELAY).timeout
	_show()


func _show() -> void:
	visible = true
	Sound.play(&"run_card")
	var secs := int(GameState.run_time)
	_values[0].text = "%d:%02d" % [floori(secs / 60.0), secs % 60]
	_values[1].text = Fmt.num(GameState.mechs_built)
	_next.text = "THIS WAR STARTS OVER" if GameState.prestige == 0 else "THIS WAR STARTS OVER\nYOUR %d WARS WON STAY" % GameState.prestige
	_card.visible = true
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.6, 0.6)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "color:a", 0.75, 0.2)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.2)


func _try_again() -> void:
	_again.disabled = true
	Save.reset_run()
