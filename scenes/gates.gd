class_name Gates
extends Node2D

const WALL := preload("res://art/battlefield/gate_wall.png")
const DOOR := preload("res://art/battlefield/gate_door.png")
const DIGITS := preload("res://art/battlefield/gate_digits.png")
const DOORS := 5
const CELL := 12.0
const BOTTOM := 160.0
const OPEN_TIME := 0.8
const BLINK := 0.25

enum Lamp { OFF, PAUSED, STARVED, ON }

var _open := {}
var _shown := []


func _ready() -> void:
	GameState.mech_deployed.connect(func(m: MechState) -> void: _open[mini(m.line, DOORS - 1)] = OPEN_TIME)
	GameState.line_added.connect(func(i: int) -> void:
		if i < DOORS:
			Fx.puff(get_parent(), position + door(i) + Vector2(0, -6), 1.2, Pal.STEEL_L))


static func door(line: int) -> Vector2:
	return Vector2(5, BOTTOM - mini(line, DOORS - 1) * CELL - 1)


static func lamp(line: LineState) -> Lamp:
	if not line.is_complete():
		return Lamp.OFF
	if line.paused:
		return Lamp.PAUSED
	return Lamp.STARVED if line.starved() else Lamp.ON


func _process(delta: float) -> void:
	var blink := int(Time.get_ticks_msec() / (BLINK * 1000.0)) % 2 == 0
	var shown := []
	for i in mini(GameState.lines.size(), DOORS):
		_open[i] = maxf(0.0, float(_open.get(i, 0.0)) - delta)
		var state := lamp(GameState.lines[i])
		shown.append([_open[i] > 0.0, state if state != Lamp.STARVED or blink else Lamp.OFF])
	if shown != _shown:
		_shown = shown
		queue_redraw()


func _draw() -> void:
	draw_texture(WALL, Vector2(0, BOTTOM - WALL.get_height()))
	for i in _shown.size():
		var top := Vector2(0, BOTTOM - (i + 1) * CELL)
		draw_texture_rect_region(DOOR, Rect2(top + Vector2(1, 2), Vector2(9, 10)), Rect2(9 if _shown[i][0] else 0, 0, 9, 10))
		draw_rect(Rect2(top + Vector2(11, 4), Vector2(5, 7)), Pal.INK)
		draw_rect(Rect2(top + Vector2(11, 4), Vector2(4, 6)), Pal.line(i))
		draw_texture_rect_region(DIGITS, Rect2(top + Vector2(12, 5), Vector2(3, 5)), Rect2(i * 3, 0, 3, 5))
		var color: Color = {Lamp.OFF: Pal.INK, Lamp.PAUSED: Pal.SLATE, Lamp.STARVED: Pal.RED, Lamp.ON: Pal.GREEN}[_shown[i][1]]
		draw_rect(Rect2(top + Vector2(12, 1), Vector2(2, 2)), color)
