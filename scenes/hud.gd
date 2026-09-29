class_name Hud
extends Control

signal settings_pressed

const ICON_Y := 6.0
const RATE_Y := 26.0
const RATE_COLOR := Color(1, 1, 1, 0.7)
const STARVED := Color(1.0, 0.3, 0.25)

var _icons: Array[TextureRect] = []
var _credits: Label
var _credits_rate: Label
var _scrap: Label
var _scrap_rate: Label


func _ready() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_credits = _amount(preload("res://art/ui/credits.png"), 168, Color(1.0, 0.83, 0.3))
	_credits_rate = _rate(168)
	_scrap = _amount(preload("res://art/ui/scrap.png"), 8, Color(0.86, 0.86, 0.82))
	_scrap_rate = _rate(8)

	var gear := Button.new()
	gear.name = "SettingsButton"
	gear.icon = preload("res://art/ui/gear.png")
	gear.flat = true
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	gear.offset_left = -44
	gear.pressed.connect(settings_pressed.emit)
	add_child(gear)


func _process(_delta: float) -> void:
	_credits.text = Fmt.num(GameState.credits)
	_credits_rate.text = Fmt.rate(GameState.credits_rate)
	_scrap.text = Fmt.num(GameState.scrap)
	_scrap_rate.text = Fmt.rate(GameState.scrap_rate)
	_scrap_rate.modulate = STARVED if GameState.starved() else RATE_COLOR


func target(kind: Flyers.Kind) -> Vector2:
	return _icons[kind].get_global_rect().get_center()


func pulse(kind: Flyers.Kind) -> void:
	var icon := _icons[kind]
	icon.scale = Vector2(1.4, 1.4)
	icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.15)


func pulse_out(kind: Flyers.Kind) -> void:
	var icon := _icons[kind]
	icon.scale = Vector2(0.7, 0.7)
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
	label.position = Vector2(x + 22, ICON_Y - 4)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _rate(x: float) -> Label:
	var label := Label.new()
	label.position = Vector2(x, RATE_Y)
	label.modulate = RATE_COLOR
	add_child(label)
	return label
