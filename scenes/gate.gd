class_name Gate
extends Node2D

signal left(m: MechState)
signal arrived(m: MechState)

const WALL := preload("res://art/battlefield/gate_wall.png")
const DOOR := preload("res://art/battlefield/gate_door.png")
const X := -9.0
const BOTTOM := 160.0
const DOOR_POS := Vector2(3, 14)
const EXIT := Vector2(5, 159)
const OPEN_TIME := 0.8
const SLIDE_TIME := 0.15
const FLOW_GAP := 0.25
const FLOW_QUEUE := 8
const HIT_FLASH := 0.1

var health := 1.0

var _open := 0.0
var _lift := 0.0
var _shown := 0
var _queue := []
var _walkers := []
var _gap := 0.0
var _bar_px := -1
var _flash := 0.0


func _ready() -> void:
	GameState.mech_deployed.connect(func(_m: MechState) -> void: _open = OPEN_TIME)


func send(m: MechState, to: Vector2) -> bool:
	if _queue.size() >= FLOW_QUEUE:
		return false
	_queue.append({"m": m, "to": to, "pos": EXIT})
	return true


func hit() -> void:
	_flash = HIT_FLASH
	queue_redraw()


func clear() -> void:
	_queue.clear()
	_walkers.clear()
	queue_redraw()


func _process(delta: float) -> void:
	var step := delta * maxf(GameState.time_scale, 1.0)
	var moving := not _walkers.is_empty()
	var walking := []
	for w: Dictionary in _walkers:
		w.pos = (w.pos as Vector2).move_toward(w.to, Battlefield.WALK_SPEED * step)
		if w.pos == w.to:
			arrived.emit(w.m)
		else:
			walking.append(w)
	_walkers = walking
	_gap = maxf(0.0, _gap - step)
	if _gap == 0.0 and not _queue.is_empty():
		_walkers.append(_queue.pop_front())
		_gap = FLOW_GAP
		_open = OPEN_TIME
		left.emit(_walkers.back().m)
	_open = maxf(0.0, _open - delta)
	_lift = move_toward(_lift, 1.0 if _open > 0.0 else 0.0, delta / SLIDE_TIME)
	var shown := roundi(DOOR.get_height() * (1.0 - _lift))
	var bar_px := -1 if health >= 1.0 else ceili((Battlefield.GATE_BAR.size.x - 2.0) * maxf(health, 0.0))
	var flashing := _flash > 0.0
	_flash = maxf(0.0, _flash - delta)
	if shown != _shown or bar_px != _bar_px or flashing or moving or not _walkers.is_empty():
		_shown = shown
		_bar_px = bar_px
		queue_redraw()


func _draw() -> void:
	var top := Vector2(X, BOTTOM - WALL.get_height())
	var tint := Color(2, 1.4, 1.4) if _flash > 0.0 else Color.WHITE
	draw_texture(WALL, top, tint)
	var door := Vector2(DOOR.get_width(), _shown)
	draw_texture_rect_region(DOOR, Rect2(top + DOOR_POS, door), Rect2(Vector2(0, DOOR.get_height() - _shown), door), tint)
	if _bar_px >= 0:
		var bar := Battlefield.GATE_BAR
		draw_rect(bar, Pal.INK)
		draw_rect(Rect2(bar.position + Vector2.ONE, bar.size - Vector2(2, 2)), Pal.NAVY)
		draw_rect(Rect2(bar.position + Vector2.ONE, Vector2(_bar_px, bar.size.y - 2.0)), Pal.GREEN if health > 0.5 else Pal.GOLD if health > 0.25 else Pal.RED)
	var tick := int(Time.get_ticks_msec() / (Crowd.MARCH_TICK * 1000.0))
	for w: Dictionary in _walkers:
		var m: MechState = w.m
		Crowd.draw_mech(self, (w.pos as Vector2).round(), int(m.parts.get("frame", 0)), (tick + m.id) % 2, Crowd.SHADE)
