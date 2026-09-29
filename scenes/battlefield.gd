class_name Battlefield
extends Control

const GROUND_Y := 138.0
const BACK_Y := 126.0
const SLOTS_PER_ROW := 6
const SLOT_X0 := 196.0
const SLOT_DX := 24.0
const WALK_SPEED := 40.0
const ENTRY_X := -16.0
const ENEMY_X := [300.0, 322.0, 344.0]

var _mechs: Node2D
var _enemies: Array[Sprite2D] = []
var _views := {}
var _slots := {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.texture = preload("res://art/battlefield/bg.png")
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	for i in ENEMY_X.size():
		var e := Sprite2D.new()
		e.texture = preload("res://art/battlefield/enemy_1.png")
		e.offset = Vector2(0, -10)
		e.position = Vector2(ENEMY_X[i], GROUND_Y - (6.0 if i % 2 else 0.0))
		add_child(e)
		_enemies.append(e)

	_mechs = Node2D.new()
	add_child(_mechs)

	GameState.mech_deployed.connect(_on_deployed)
	GameState.mech_income.connect(_on_income)
	GameState.enemy_killed.connect(_on_kill)
	GameState.mech_died.connect(_on_died)
	for m in GameState.field:
		var view := _add_view(m)
		if view:
			view.position = _slot_pos(_slots[m.id])


func mech_count() -> int:
	return _views.size()


func _process(delta: float) -> void:
	for m in GameState.field:
		if not _views.has(m.id):
			_add_view(m)
	var step := WALK_SPEED * delta * GameState.time_scale
	for id: int in _views:
		var view: MechView = _views[id]
		var target := _slot_pos(_slots[id])
		view.position.x = move_toward(view.position.x, target.x, step)
		view.position.y = target.y


func _add_view(m: MechState) -> MechView:
	var slot := _free_slot()
	if slot == -1:
		return null
	var view := MechView.new()
	view.set_parts(m.parts)
	view.position = Vector2(ENTRY_X, _slot_pos(slot).y)
	view.modulate = Color(0.75, 0.75, 0.8) if slot >= SLOTS_PER_ROW else Color.WHITE
	_mechs.add_child(view)
	if slot >= SLOTS_PER_ROW:
		_mechs.move_child(view, 0)
	_views[m.id] = view
	_slots[m.id] = slot
	return view


func _free_slot() -> int:
	var used := _slots.values()
	for i in SLOTS_PER_ROW * 2:
		if not used.has(i):
			return i
	return -1


func _slot_pos(slot: int) -> Vector2:
	var row := 1 if slot >= SLOTS_PER_ROW else 0
	var col := slot % SLOTS_PER_ROW
	var x := SLOT_X0 - col * SLOT_DX - row * SLOT_DX / 2.0
	return Vector2(x, BACK_Y if row else GROUND_Y)


func _fly(m: MechState, kind: Flyers.Kind, count: int) -> void:
	var view: MechView = _views.get(m.id)
	if view:
		Flyers.spawn(kind, view.global_position + Vector2(0, -34), count)


func _on_deployed(m: MechState) -> void:
	var view := _add_view(m)
	if view:
		_fly(m, Flyers.Kind.CREDITS, 3)


func _on_income(m: MechState, credits: float, scrap: float) -> void:
	if credits > 0.0:
		_fly(m, Flyers.Kind.CREDITS, 1)
	if scrap > 0.0:
		_fly(m, Flyers.Kind.SCRAP, 1)


func _on_kill(_m: MechState) -> void:
	var e: Sprite2D = _enemies.pick_random()
	e.modulate = Color(3, 3, 3)
	e.create_tween().tween_property(e, "modulate", Color.WHITE, 0.2)


func _on_died(m: MechState, salvage: float) -> void:
	var view: MechView = _views.get(m.id)
	if view == null:
		return
	if salvage > 0.0:
		_fly(m, Flyers.Kind.SCRAP, 2)
	_views.erase(m.id)
	_slots.erase(m.id)
	view.pop()
