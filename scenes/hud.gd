class_name Hud
extends Control

signal settings_pressed

const ICON_Y := 6.0
const BUTTON_W := 40.0
const COLUMN_W := 85.0
const WARS_X := 274.0
const WARS_W := 24.0
const SOUND_ON := preload("res://art/ui/sound_on.png")
const SOUND_OFF := preload("res://art/ui/sound_off.png")
const LEFT := 6.0
const RATE_Y := 26.0
const RATE_COLOR := Color(1, 1, 1, 0.7)
const STARVED := Pal.RED

var _icons: Array[TextureRect] = []
var _credits: Label
var _credits_rate: Label
var _scrap: Label
var _scrap_rate: Label
var _mechs: Label
var _mechs_rate: Label
var _mech_icon: TextureRect
var _wars_icon: TextureRect
var _wars: Label
var _won := 0
var _mute: Button
var _late: Array[CanvasItem] = []
var _late_k := 0.0


func _ready() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_credits = _amount(preload("res://art/ui/credits.png"), _column(2), Price.COLORS[Flyers.Kind.CREDITS])
	_credits_rate = _rate(_column(2))
	_credits_rate.name = "CreditsRate"
	_scrap = _amount(preload("res://art/ui/scrap.png"), _column(0), Price.COLORS[Flyers.Kind.SCRAP])
	_scrap_rate = _rate(_column(0))
	_mechs = _amount(preload("res://art/ui/mech.png"), _column(1), Pal.CYAN)
	_mechs.name = "Mechs"
	_mech_icon = _icons.pop_back()
	_mechs_rate = _rate(_column(1))
	_mechs_rate.name = "MechsRate"
	_wars = _amount(preload("res://art/ui/nuclear.png"), WARS_X - 8.0, Pal.ORANGE)
	_wars.name = "Wars"
	_wars.position = Vector2(WARS_X - WARS_W / 2.0, RATE_Y)
	_wars.size.x = WARS_W
	_wars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wars_icon = _icons.pop_back()
	_show_wars()
	GameState.mech_deployed.connect(_on_deployed)
	_late = [_icons[Flyers.Kind.CREDITS], _credits, _credits_rate, _mech_icon, _mechs, _mechs_rate]
	_late_k = Reveal.step(0.0, GameState.revealed(), INF)
	_fade_late()

	var gear := _icon_button("SettingsButton", preload("res://art/ui/gear.png"), 0)
	gear.set_meta(&"silent", true)
	gear.pressed.connect(settings_pressed.emit)
	_mute = _icon_button("MuteButton", SOUND_OFF if Sound.muted else SOUND_ON, 1)
	_mute.pressed.connect(func() -> void: Sound.set_muted(not Sound.muted))


func _process(delta: float) -> void:
	var late := Reveal.step(_late_k, GameState.revealed(), delta, Reveal.SLIDE_TIME)
	if late != _late_k:
		_late_k = late
		_fade_late()
	_credits.text = Fmt.num(GameState.credits)
	_credits_rate.text = Fmt.rate(GameState.credits_rate)
	_scrap.text = Fmt.num(GameState.scrap)
	_scrap_rate.text = Fmt.rate(GameState.scrap_rate)
	_scrap_rate.modulate = STARVED if GameState.starved() else RATE_COLOR
	_mechs.text = Fmt.num(GameState.field.size())
	_mechs_rate.text = "%d/MIN" % GameState.mechs_per_min
	_show_wars()
	var icon := SOUND_OFF if Sound.muted else SOUND_ON
	if _mute.icon != icon:
		_mute.icon = icon


func _show_wars() -> void:
	var wars := GameState.prestige + _won
	_wars_icon.visible = wars > 0
	_wars.visible = wars > 0
	_wars.text = str(wars)


func _fade_late() -> void:
	for c in _late:
		c.visible = _late_k > 0.0
		c.self_modulate.a = Reveal.eased(_late_k)


func _icon_button(node_name: String, tex: Texture2D, slot: int) -> Button:
	var b := Button.new()
	b.name = node_name
	b.icon = tex
	b.flat = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	b.offset_left = -BUTTON_W * (slot + 1)
	b.offset_right = -BUTTON_W * slot
	add_child(b)
	return b


func _column(i: int) -> float:
	return LEFT + i * COLUMN_W


func target(kind: Flyers.Kind) -> Vector2:
	return _icons[kind].get_global_rect().get_center()


func pulse(kind: Flyers.Kind) -> void:
	_bump(_icons[kind], 1.4)


func pulse_out(kind: Flyers.Kind) -> void:
	_bump(_icons[kind], 0.7)


func wars_target() -> Vector2:
	return _wars_icon.get_global_rect().get_center()


func win() -> void:
	_won = 1
	_show_wars()
	_bump(_wars_icon, 1.4)


func _on_deployed(_m: MechState) -> void:
	_bump(_mech_icon, 1.4)


func _bump(icon: TextureRect, from: float) -> void:
	icon.scale = Vector2(from, from)
	icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.15)


func _amount(icon_tex: Texture2D, x: float, color: Color) -> Label:
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.position = Vector2(x, ICON_Y)
	icon.pivot_offset = icon_tex.get_size() / 2.0
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(icon)
	_icons.append(icon)
	var label := Label.new()
	label.position = Vector2(x + 22, ICON_Y - 2)
	label.add_theme_color_override("font_color", color)
	label.z_index = Main.TEXT_Z
	add_child(label)
	return label


func _rate(x: float) -> Label:
	var label := Label.new()
	label.position = Vector2(x, RATE_Y)
	label.modulate = RATE_COLOR
	label.z_index = Main.TEXT_Z
	add_child(label)
	return label
