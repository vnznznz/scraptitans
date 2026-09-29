class_name Hud
extends Control

signal settings_pressed

var _credits: Label
var _credits_rate: Label
var _scrap: Label
var _scrap_rate: Label


func _ready() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_credits = _amount(preload("res://art/ui/credits.png"), 8, Color(1.0, 0.83, 0.3))
	_credits_rate = _rate(26)
	_scrap = _amount(preload("res://art/ui/scrap.png"), 150, Color(0.86, 0.86, 0.82))
	_scrap_rate = _rate(168)

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


func _amount(icon_tex: Texture2D, x: float, color: Color) -> Label:
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.position = Vector2(x, 6)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(icon)
	var label := Label.new()
	label.position = Vector2(x + 18, -2)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _rate(x: float) -> Label:
	var label := Label.new()
	label.position = Vector2(x, 20)
	add_child(label)
	return label
