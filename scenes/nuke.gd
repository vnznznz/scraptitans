class_name Nuke
extends Control

const SWEEP_TIME := 3.0
const COUNT_TIME := 1.2
const MUSIC_DELAY := 1.5
const WIN_FLY := 0.6
const WIN_HOLD := 0.6
const NUCLEAR := preload("res://art/ui/nuclear.png")

@export var battlefield: Battlefield
@export var scroll: ScrollContainer
@export var lines: Control
@export var scrapyard: Scrapyard
@export var rail: ScrollRail
@export var hud: Hud

var _flash: ColorRect
var _band: TextureRect
var _card: PanelContainer
var _again: Button
var _values: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_flash)

	_band = TextureRect.new()
	_band.texture = preload("res://art/fx/shockwave.png")
	_band.visible = false
	_band.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_band)

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
	var icon := TextureRect.new()
	icon.texture = preload("res://art/ui/nuke.png")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	box.add_child(icon)
	var title := Label.new()
	title.text = "THE WAR IS OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Pal.ORANGE)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "ONLY SCRAP REMAINS"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)
	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 2)
	box.add_child(stats)
	for row: Array in [[preload("res://art/ui/life.png"), "TIME", Pal.STEEL_L], [preload("res://art/ui/mech.png"), "MECHS", Pal.CYAN], [preload("res://art/ui/credits.png"), "CREDITS", Pal.GOLD],
			[NUCLEAR, "WARS WON", Pal.ORANGE]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		stats.add_child(h)
		var i := TextureRect.new()
		i.texture = row[0]
		i.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(i)
		var k := Label.new()
		k.text = row[1]
		k.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(k)
		var v := Label.new()
		v.add_theme_color_override("font_color", row[2])
		h.add_child(v)
		_values.append(v)
	var next := Label.new()
	next.name = "Next"
	next.text = "NEXT WAR: EVERYTHING %s\nYOUR PILE %s" % [_times("prestige_scale"), _times("prestige_pile")]
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	next.modulate = Color(1, 1, 1, 0.6)
	box.add_child(next)
	_again = Button.new()
	_again.name = "StartAgain"
	_again.text = "START AGAIN"
	_again.icon = NUCLEAR
	_again.theme_type_variation = &"LitButton"
	_again.custom_minimum_size = Vector2(0, 44)
	_again.pressed.connect(_start_again)
	box.add_child(_again)

	GameState.nuke_launched.connect(_play)
	if GameState.run_over:
		_collapse_all()
		_show_card()


func card_visible() -> bool:
	return _card.visible


func _times(key: String) -> String:
	var v := Data.econ(key)
	return "X%s" % (str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.1)))


func _start_again() -> void:
	_again.disabled = true
	var half := NUCLEAR.get_size() / 2.0
	var from := _again.get_global_rect().get_center()
	var disc := TextureRect.new()
	disc.texture = NUCLEAR
	disc.mouse_filter = MOUSE_FILTER_IGNORE
	disc.position = from - half
	add_child(disc)
	var tw := disc.create_tween()
	tw.tween_property(disc, "position", from + Vector2(0, -28) - half, WIN_FLY * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(disc, "position", hud.wars_target() - half, WIN_FLY * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	disc.queue_free()
	hud.win()
	Sound.play(&"buy_tier")
	await get_tree().create_timer(WIN_HOLD).timeout
	await CrazyGames.request_ad("midgame")
	Save.start_again()


func _play(m: MechState) -> void:
	visible = true
	get_tree().call_group("upgrade_menu", "close")
	rail.release()
	await battlefield.fire_missile(m.id)
	await get_tree().create_timer(0.3).timeout
	_flash.color = Color.WHITE
	Sound.play(&"nuke_blast")
	Sound.play(&"nuke_rumble")
	battlefield.mushroom()
	_shake(6.0, 1.6)
	var tw := create_tween()
	tw.tween_property(_flash, "color", Color(Pal.YELLOW, 0.8), 0.25)
	tw.tween_property(_flash, "color", Color(Pal.ORANGE, 0.0), 1.0)
	await get_tree().create_timer(1.6).timeout
	await _sweep()
	await get_tree().create_timer(0.6).timeout
	_show_card()


func _sweep() -> void:
	_band.visible = true
	_band.size = Vector2(size.x, _band.texture.get_height())
	_shake(2.0, SWEEP_TIME)
	Sound.play(&"shockwave")
	Sound.play(&"shockwave_boom")
	var targets := lines.get_children().filter(func(c: Node) -> bool: return c is Control and c.visible)
	targets.append(scrapyard)
	var from := lines.position.y
	var total := (lines.get_parent() as Control).size.y
	var tw := create_tween()
	tw.tween_method(func(p: float) -> void:
		var y := lerpf(from, total, p)
		scroll.scroll_vertical = int(y - scroll.size.y / 2.0)
		_band.position.y = scroll.global_position.y + y - scroll.scroll_vertical - _band.size.y / 2.0
		for c: Control in targets.duplicate():
			if y >= c.position.y + c.size.y / 2.0 + (from if c.get_parent() == lines else 0.0):
				targets.erase(c)
				if c.has_method("collapse"):
					Sound.play(&"collapse")
				_collapse(c), 0.0, 1.0, SWEEP_TIME)
	await tw.finished
	_band.visible = false


func _collapse_all() -> void:
	for c in lines.get_children():
		_collapse(c)
	scrapyard.collapse()


func _collapse(c: Node) -> void:
	if c.has_method("collapse"):
		c.collapse()
	elif c is CanvasItem:
		c.visible = false


func _shake(strength: float, time: float) -> void:
	var layout := get_parent().get_node("Layout") as Control
	var rest := Vector2(0.0, layout.offset_top)
	var tw := create_tween()
	var steps := int(time / 0.04)
	for k in steps:
		var fade := 1.0 - float(k) / steps
		tw.tween_property(layout, "position", rest + Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * strength * fade, 0.04)
	tw.tween_property(layout, "position", rest, 0.04)


func _show_card() -> void:
	visible = true
	Sound.play(&"run_card")
	create_tween().tween_callback(Sound.play_music).set_delay(MUSIC_DELAY)
	var t := int(GameState.run_time)
	var targets := [float(t), float(GameState.mechs_built), GameState.credits_earned]
	_values[3].text = "%d » %d" % [GameState.prestige, GameState.prestige + 1]
	_card.visible = true
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.6, 0.6)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	tw.chain().tween_method(func(k: float) -> void:
		var secs := int(targets[0] * k)
		_values[0].text = "%d:%02d" % [floori(secs / 60.0), secs % 60]
		_values[1].text = Fmt.num(roundf(targets[1] * k))
		_values[2].text = Fmt.num(roundf(targets[2] * k)), 0.0, 1.0, COUNT_TIME).set_ease(Tween.EASE_OUT)
