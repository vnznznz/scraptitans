class_name Scrapyard
extends Control

const PILE_TEX := preload("res://art/yard/pile.png")
const WORKER_TEX := preload("res://art/yard/worker.png")
const WORKERS_X := 14.0
const WORKERS_Y := 100.0
const WORKER_DX := 12.0

var _pile: TextureRect
var _tap: TapArea
var _hire: Button
var _workers: Array[TextureRect] = []
var _chunks_seen := 0
var _collapsed := false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 166)
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

	_hire = Button.new()
	_hire.name = "HireYard"
	_hire.icon = preload("res://art/ui/worker.png")
	_hire.size = Vector2(240, 36)
	_hire.mouse_filter = MOUSE_FILTER_PASS
	_hire.pressed.connect(func() -> void: GameState.hire_yard_worker())
	add_child(_hire)
	_chunks_seen = GameState.yard_chunks
	resized.connect(_layout)
	_layout()


func pile() -> TapArea:
	return _tap


func _layout() -> void:
	var cx := size.x / 2.0
	_pile.size = PILE_TEX.get_size()
	_pile.position = Vector2(cx - _pile.size.x / 2.0, 50)
	_pile.pivot_offset = Vector2(_pile.size.x / 2.0, _pile.size.y)
	_tap.position = Vector2(cx - _tap.size.x / 2.0, 30)
	_hire.position = Vector2(cx - _hire.size.x / 2.0, 124)


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
		var w := TextureRect.new()
		w.texture = WORKER_TEX
		w.mouse_filter = MOUSE_FILTER_IGNORE
		w.position = Vector2(WORKERS_X + _workers.size() * WORKER_DX, WORKERS_Y)
		add_child(w)
		_workers.append(w)
	var n := GameState.yard_workers
	for i in _workers.size():
		_workers[i].visible = i < slots and GameState.revealed()
		_workers[i].modulate = Color.WHITE if i < n else Color(0.4, 0.4, 0.45, 0.5)
	if GameState.yard_chunks != _chunks_seen and n > 0:
		var w := _workers[(GameState.yard_chunks - 1) % n]
		var tw := w.create_tween()
		tw.tween_property(w, "position:y", WORKERS_Y - 4, 0.08)
		tw.tween_property(w, "position:y", WORKERS_Y, 0.1)
		Flyers.spawn(Flyers.Kind.SCRAP, w.global_position + Vector2(5, -4), GameState.yard_chunk())
	_chunks_seen = GameState.yard_chunks
	_hire.visible = GameState.revealed()
	var maxed := n >= slots
	var cost := GameState.yard_worker_cost()
	_hire.text = "YARD WORKER  " + ("MAX" if maxed else Fmt.num(cost))
	_hire.disabled = maxed or GameState.credits < cost


func _on_tap(at: Vector2) -> void:
	GameState.tap_pile()
	Flyers.spawn(Flyers.Kind.SCRAP, _tap.global_position + at + Vector2(0, -28), GameState.stat("scrap_per_tap"))
	var tw := _pile.create_tween()
	_pile.scale = Vector2(1.06, 0.92)
	tw.tween_property(_pile, "scale", Vector2.ONE, 0.12)
