class_name Scrapyard
extends Control

const PILE_TEX := preload("res://art/yard/pile.png")
const WORKER_TEX := preload("res://art/yard/worker.png")
const PILE_POS := Vector2(62, 32)
const PILE_EDGES := Vector2(75, 163)
const GROUND_Y := 96.0
const WORKER_DX := 7.0
const HIRE_RECT := Rect2(240, 6, 114, 40)

var _pile: TextureRect
var _tap: TapArea
var _hire: Button
var _workers: Array[TextureRect] = []
var _chunks_seen := 0
var _collapsed := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	_pile = TextureRect.new()
	_pile.texture = PILE_TEX
	_pile.position = PILE_POS
	_pile.pivot_offset = Vector2(PILE_TEX.get_width() / 2.0, PILE_TEX.get_height())
	_pile.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_pile)

	_tap = TapArea.new()
	_tap.name = "Pile"
	_tap.position = Vector2(40, 8)
	_tap.size = Vector2(160, 92)
	_tap.tapped.connect(_on_tap)
	add_child(_tap)

	_hire = Button.new()
	_hire.name = "HireYard"
	_hire.icon = preload("res://art/ui/worker.png")
	_hire.position = HIRE_RECT.position
	_hire.size = HIRE_RECT.size
	_hire.pressed.connect(func() -> void: GameState.hire_yard_worker())
	add_child(_hire)
	_chunks_seen = GameState.yard_chunks


func pile() -> TapArea:
	return _tap


func collapse() -> void:
	_collapsed = true
	_hire.visible = false
	for w in _workers:
		w.visible = false


func _process(_delta: float) -> void:
	if _collapsed:
		return
	var slots := GameState.yard_slots()
	while _workers.size() < slots:
		var i := _workers.size()
		var j := int(i / 2.0)
		var w := TextureRect.new()
		w.texture = WORKER_TEX
		w.mouse_filter = MOUSE_FILTER_IGNORE
		w.flip_h = i % 2 == 1
		w.position = _home(i)
		w.modulate = Color.WHITE.darkened(0.25) if j % 2 == 1 else Color.WHITE
		add_child(w)
		move_child(w, _pile.get_index())
		_workers.append(w)
	var n := GameState.yard_workers
	for i in _workers.size():
		_workers[i].visible = i < n
	if GameState.yard_chunks != _chunks_seen and n > 0:
		_dig((GameState.yard_chunks - 1) % n)
	_chunks_seen = GameState.yard_chunks
	var cost := GameState.yard_worker_cost()
	_hire.visible = GameState.revealed() and n < slots
	_hire.text = Fmt.num(cost)
	_hire.disabled = GameState.credits < cost


func _home(i: int) -> Vector2:
	var j := int(i / 2.0)
	var h := WORKER_TEX.get_height()
	var w := WORKER_TEX.get_width()
	var y := GROUND_Y - h - (j % 2) * 4.0
	if i % 2 == 0:
		return Vector2(PILE_EDGES.x - w - 4.0 - j * WORKER_DX, y)
	return Vector2(PILE_EDGES.y + 4.0 + j * WORKER_DX, y)


func _dig(i: int) -> void:
	var w := _workers[i]
	var home := _home(i)
	var hit_x := PILE_EDGES.x - WORKER_TEX.get_width() + 2.0 if i % 2 == 0 else PILE_EDGES.y - 2.0
	var speed := maxf(GameState.time_scale, 1.0)
	if w.has_meta("tween"):
		(w.get_meta("tween") as Tween).kill()
	var tw := w.create_tween()
	w.set_meta("tween", tw)
	w.position = home
	tw.tween_property(w, "position:x", hit_x, (0.1 + absf(hit_x - home.x) / 300.0) / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_squash(0.97)
		Flyers.spawn(Flyers.Kind.SCRAP, w.global_position + Vector2(WORKER_TEX.get_width() / 2.0, -4), GameState.yard_chunk()))
	tw.tween_property(w, "position", Vector2((hit_x + home.x) / 2.0, home.y - 4.0), 0.1 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "position", home, 0.12 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _squash(y_scale: float) -> void:
	_pile.scale = Vector2(2.0 - y_scale, y_scale)
	_pile.create_tween().tween_property(_pile, "scale", Vector2.ONE, 0.12)


func _on_tap(at: Vector2) -> void:
	GameState.tap_pile()
	Flyers.spawn(Flyers.Kind.SCRAP, _tap.global_position + at + Vector2(0, -28), GameState.stat("scrap_per_tap"))
	_squash(0.92)
