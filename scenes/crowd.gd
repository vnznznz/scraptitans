class_name Crowd
extends Node2D

const TEX := preload("res://art/mech/crowd.png")
const CELL := Vector2(16, 24)
const ROW_Y := [112.0, 115.0, 118.0, 121.0, 124.0]
const X0 := 10.0
const DX := 7.0
const COLUMNS := 31
const ROW_SHIFT := 3.0
const SHADE := Color(0.5, 0.5, 0.56)
const IDLE_TICK := 0.4
const MARCH_TICK := 0.15

var marching := false

var _members := {}
var _tiers := {}
var _rank: Array[int] = []
var _by_rank: Array[int] = []
var _tick := 0
var _t := 0.0


func _init() -> void:
	var n := ROW_Y.size() * COLUMNS
	_by_rank.assign(range(n))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := _by_rank[i]
		_by_rank[i] = _by_rank[j]
		_by_rank[j] = swap
	_rank.resize(n)
	for r in n:
		_rank[_by_rank[r]] = r
	modulate = SHADE


func count() -> int:
	return _members.size()


func has(id: int) -> bool:
	return _members.has(id)


func spot(id: int) -> Vector2:
	return _position(_members[id])


func remove(id: int) -> void:
	_tiers.erase(_members[id])
	_members.erase(id)
	queue_redraw()


func clear() -> void:
	_members.clear()
	_tiers.clear()
	queue_redraw()


func sync(field: Array[MechState], drawn: Dictionary, cap: int) -> void:
	var undrawn := {}
	for m in field:
		if not drawn.has(m.id):
			undrawn[m.id] = true
	for id: int in _members.keys():
		if not undrawn.has(id) or _rank[_members[id]] >= cap:
			remove(id)
	var r := 0
	for m in field:
		if not undrawn.has(m.id) or _members.has(m.id):
			continue
		while r < cap and _tiers.has(_by_rank[r]):
			r += 1
		if r >= cap:
			break
		_members[m.id] = _by_rank[r]
		_tiers[_by_rank[r]] = int(m.parts.get("frame", 0))
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t < (MARCH_TICK if marching else IDLE_TICK):
		return
	_t = 0.0
	_tick += 1
	if not _members.is_empty():
		queue_redraw()


func _draw() -> void:
	for slot in _rank.size():
		if not _tiers.has(slot):
			continue
		var f := (slot + _tick) % 2 if marching else int((slot * 7 + _tick) % 4 == 0)
		var p := _position(slot)
		draw_texture_rect_region(TEX, Rect2(p.x - CELL.x / 2.0, p.y - CELL.y, CELL.x, CELL.y),
				Rect2(f * CELL.x, _tiers[slot] * CELL.y, CELL.x, CELL.y))


func _position(slot: int) -> Vector2:
	var row := int(float(slot) / COLUMNS)
	var col := slot % COLUMNS
	var jitter := float((slot * 37) % 5 - 2)
	return Vector2(X0 + col * DX + (ROW_SHIFT if row % 2 == 1 else 0.0) + jitter, ROW_Y[row])
