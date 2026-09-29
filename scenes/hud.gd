class_name Hud
extends Control

signal settings_pressed

const ICON_Y := 6.0
const GEAR_W := 44.0
const COLUMN_W := 105.0
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


func _ready() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_credits = _amount(preload("res://art/ui/credits.png"), _column(2), Price.COLORS[Flyers.Kind.CREDITS])
	_credits_rate = _rate(_column(2))
	_scrap = _amount(preload("res://art/ui/scrap.png"), _column(0), Price.COLORS[Flyers.Kind.SCRAP])
	_scrap_rate = _rate(_column(0))
	_mechs = _amount(preload("res://art/ui/mech.png"), _column(1), Pal.CYAN)
	_mechs.name = "Mechs"
	_mech_icon = _icons.pop_back()
	_mechs_rate = _rate(_column(1))
	_mechs_rate.name = "MechsRate"
	GameState.mech_deployed.connect(_on_deployed)

	var gear := Button.new()
	gear.name = "SettingsButton"
	gear.icon = preload("res://art/ui/gear.png")
	gear.flat = true
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	gear.offset_left = -GEAR_W
	gear.pressed.connect(settings_pressed.emit)
	add_child(gear)


func _process(_delta: float) -> void:
	_credits.text = Fmt.num(GameState.credits)
	_credits_rate.text = Fmt.rate(GameState.credits_rate)
	_scrap.text = Fmt.num(GameState.scrap)
	_scrap_rate.text = Fmt.rate(GameState.scrap_rate)
	_scrap_rate.modulate = STARVED if GameState.starved() else RATE_COLOR
	_mechs.text = Fmt.num(GameState.mechs_built)
	_mechs_rate.text = "%d/MIN" % GameState.mechs_per_min


func _column(i: int) -> float:
	return LEFT + i * COLUMN_W


func target(kind: Flyers.Kind) -> Vector2:
	return _icons[kind].get_global_rect().get_center()


func pulse(kind: Flyers.Kind) -> void:
	_bump(_icons[kind], 1.4)


func pulse_out(kind: Flyers.Kind) -> void:
	_bump(_icons[kind], 0.7)


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
