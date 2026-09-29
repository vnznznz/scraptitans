class_name Scrapyard
extends Control

const PILE_TEX := preload("res://art/yard/pile_3.png")
const PILE_LEVELS := [preload("res://art/yard/pile_1.png"), preload("res://art/yard/pile_2.png"), PILE_TEX]
const PILE_SECONDS := [5.0, 30.0]
const WORKER_TEX := preload("res://art/yard/worker.png")
const PILE_POS := Vector2(62, 32)
const PILE_EDGES := Vector2(75, 163)
const GROUND_Y := 96.0
const WORKER_DX := 7.0
const HIRE_RECT := Rect2(240, 6, 114, 40)
const SLIDE_TIME := 0.4
const SQUASH_TIME := 0.12

var _yard: Control
var _pile: TextureRect
var _tap: TapArea
var _hire: Button
var _workers: Array[TextureRect] = []
var _chunks_seen := 0
var _squash_depth := 0.0
var _squash_at := -1.0
var _clock := 0.0
var _collapsed := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	_yard = Control.new()
	_yard.name = "Yard"
	_yard.mouse_filter = MOUSE_FILTER_IGNORE
	_yard.position.x = _yard_x()
	add_child(_yard)

	_pile = TextureRect.new()
	_pile.name = "PileSprite"
	_pile.texture = PILE_TEX
	_pile.position = PILE_POS
	_pile.pivot_offset = Vector2(PILE_TEX.get_width() / 2.0, PILE_TEX.get_height())
	_pile.mouse_filter = MOUSE_FILTER_IGNORE
	_yard.add_child(_pile)

	_tap = TapArea.new()
	_tap.name = "Pile"
	_tap.position = Vector2(40, 8)
	_tap.size = Vector2(160, 92)
	_tap.highlight = _pile
	_tap.tapped.connect(_on_tap)
	_yard.add_child(_tap)

	_hire = Button.new()
	_hire.name = "HireYard"
	_hire.icon = preload("res://art/ui/worker.png")
	_hire.position = HIRE_RECT.position
	_hire.size = HIRE_RECT.size
	Price.setup(_hire, Flyers.Kind.CREDITS)
	_hire.pressed.connect(_on_hire)
	add_child(_hire)
	_chunks_seen = GameState.yard_chunks


func pile() -> TapArea:
	return _tap


func collapse() -> void:
	_collapsed = true
	_hire.visible = false
	for w in _workers:
		w.visible = false


func _process(delta: float) -> void:
	_clock += delta
	_pile.texture = PILE_LEVELS[pile_level()]
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
		_yard.add_child(w)
		_yard.move_child(w, _pile.get_index())
		_workers.append(w)
	if not GameState.revealed():
		_yard.position.x = _yard_x()
	elif _yard.position.x != 0.0 and not _yard.has_meta("sliding"):
		_yard.set_meta("sliding", true)
		var tw := _yard.create_tween()
		tw.tween_property(_yard, "position:x", _yard_x(), SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_yard.remove_meta.bind("sliding"))
	var n := GameState.yard_workers
	for i in _workers.size():
		_workers[i].visible = i < n
	if GameState.yard_chunks != _chunks_seen and n > 0:
		_dig((GameState.yard_chunks - 1) % n)
	_chunks_seen = GameState.yard_chunks
	var cost := GameState.yard_worker_cost()
	_hire.visible = GameState.revealed() and n < slots
	Price.show(_hire, Fmt.num(cost), GameState.credits >= cost)


func pile_level() -> int:
	var seconds := GameState.scrap / maxf(GameState.yard_rate(), 1.0)
	var level := 0
	for s: float in PILE_SECONDS:
		if seconds >= s:
			level += 1
	return level


func _yard_x() -> float:
	if GameState.revealed():
		return 0.0
	return size.x / 2.0 - (PILE_POS.x + PILE_TEX.get_width() / 2.0)


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
		_squash(0.97, 1.0, 0.2)
		Flyers.spawn(Flyers.Kind.SCRAP, w.global_position + Vector2(WORKER_TEX.get_width() / 2.0, -4), GameState.yard_chunk()))
	tw.tween_property(w, "position", Vector2((hit_x + home.x) / 2.0, home.y - 4.0), 0.1 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "position", home, 0.12 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _squash(y_scale: float, shake: float, rest: float) -> void:
	var depth := 1.0 - y_scale
	var elapsed := _clock - _squash_at
	if elapsed < rest or (elapsed < SQUASH_TIME and depth < _squash_depth):
		return
	_squash_depth = depth
	_squash_at = _clock
	_pile.scale = Vector2(2.0 - y_scale, y_scale)
	if _pile.has_meta("tween"):
		(_pile.get_meta("tween") as Tween).kill()
	_pile.position = PILE_POS
	var tw := _pile.create_tween()
	_pile.set_meta("tween", tw)
	tw.tween_property(_pile, "scale", Vector2.ONE, SQUASH_TIME)
	for k in 4:
		tw.parallel().tween_property(_pile, "position:x", PILE_POS.x + shake * (1.0 if k % 2 == 0 else -1.0) * (1.0 - k * 0.25), 0.03).set_delay(k * 0.03)
	tw.chain().tween_property(_pile, "position:x", PILE_POS.x, 0.03)


func _on_hire() -> void:
	var cost := GameState.yard_worker_cost()
	if GameState.hire_yard_worker():
		Flyers.pay(Flyers.Kind.CREDITS, _hire, cost)


func _on_tap(at: Vector2) -> void:
	var amount := GameState.tap_scrap()
	GameState.tap_pile()
	Flyers.spawn(Flyers.Kind.SCRAP, _tap.global_position + at + Vector2(0, -28), amount, 1, true)
	_squash(0.92, 2.0, 0.06)
