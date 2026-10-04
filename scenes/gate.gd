class_name Gate
extends Node2D

const WALL := preload("res://art/battlefield/gate_wall.png")
const DOOR := preload("res://art/battlefield/gate_door.png")
const BOTTOM := 160.0
const DOOR_POS := Vector2(3, 14)
const EXIT := Vector2(5, 159)
const OPEN_TIME := 0.8
const SLIDE_TIME := 0.15

var _open := 0.0
var _lift := 0.0
var _shown := 0


func _ready() -> void:
	GameState.mech_deployed.connect(func(_m: MechState) -> void: _open = OPEN_TIME)


func _process(delta: float) -> void:
	_open = maxf(0.0, _open - delta)
	_lift = move_toward(_lift, 1.0 if _open > 0.0 else 0.0, delta / SLIDE_TIME)
	var shown := roundi(DOOR.get_height() * (1.0 - _lift))
	if shown != _shown:
		_shown = shown
		queue_redraw()


func _draw() -> void:
	var top := Vector2(0, BOTTOM - WALL.get_height())
	draw_texture(WALL, top)
	var door := Vector2(DOOR.get_width(), _shown)
	draw_texture_rect_region(DOOR, Rect2(top + DOOR_POS, door), Rect2(Vector2(0, DOOR.get_height() - _shown), door))
