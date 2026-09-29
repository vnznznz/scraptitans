class_name Scrapyard
extends Control

const PILE_TEX := preload("res://art/yard/pile.png")

var _pile: TextureRect
var _tap: TapArea


func _ready() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = MOUSE_FILTER_PASS

	var header := Label.new()
	header.text = "SCRAPYARD"
	header.position = Vector2(8, 2)
	add_child(header)

	_pile = TextureRect.new()
	_pile.texture = PILE_TEX
	_pile.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_pile)

	_tap = TapArea.new()
	_tap.name = "Pile"
	_tap.size = Vector2(160, 110)
	_tap.tapped.connect(_on_tap)
	add_child(_tap)
	resized.connect(_layout)
	_layout()


func pile() -> TapArea:
	return _tap


func _layout() -> void:
	var cx := size.x / 2.0
	_pile.size = PILE_TEX.get_size()
	_pile.position = Vector2(cx - _pile.size.x / 2.0, 40)
	_pile.pivot_offset = Vector2(_pile.size.x / 2.0, _pile.size.y)
	_tap.position = Vector2(cx - _tap.size.x / 2.0, 20)


func _on_tap(at: Vector2) -> void:
	GameState.tap_pile()
	Floater.spawn(self, _tap.position + at, "+" + Fmt.num(Data.econ("scrap_per_tap")), Floater.GREY)
	var tw := _pile.create_tween()
	_pile.scale = Vector2(1.06, 0.92)
	tw.tween_property(_pile, "scale", Vector2.ONE, 0.12)
