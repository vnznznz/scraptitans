class_name Battlefield
extends Control

const GROUND_Y := 138.0
const BACK_Y := 126.0
const AIR_Y := 84.0
const SLOTS_PER_ROW := 6
const SLOT_X0 := 196.0
const SLOT_DX := 24.0
const WALK_SPEED := 40.0
const ENTRY_X := -16.0
const ENEMY_X0 := 258.0
const ENEMY_X1 := 346.0
const ENEMY_WALK_IN := 1.2
const BAR_RECT := Rect2(4, 4, 352, 20)

var _mechs: Node2D
var _enemy_layer: Node2D
var _enemies: Array[Sprite2D] = []
var _enemy_count := 0
var _wave_shown := -1
var _views := {}
var _slots := {}
var _bar: TextureProgressBar
var _hp_label: Label
var _dps_label: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.texture = preload("res://art/battlefield/bg.png")
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_enemy_layer = Node2D.new()
	add_child(_enemy_layer)
	_mechs = Node2D.new()
	add_child(_mechs)

	_bar = TextureProgressBar.new()
	_bar.name = "WaveBar"
	_bar.texture_under = preload("res://art/ui/bar_under.png")
	_bar.texture_progress = preload("res://art/ui/hp_fill.png")
	_bar.nine_patch_stretch = true
	_bar.stretch_margin_left = 2
	_bar.stretch_margin_top = 2
	_bar.stretch_margin_right = 2
	_bar.stretch_margin_bottom = 2
	_bar.position = BAR_RECT.position
	_bar.size = BAR_RECT.size
	_bar.step = 0.0
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bar)
	_hp_label = _bar_label(HORIZONTAL_ALIGNMENT_LEFT)
	_dps_label = _bar_label(HORIZONTAL_ALIGNMENT_RIGHT)

	GameState.mech_deployed.connect(_on_deployed)
	GameState.mech_income.connect(_on_income)
	GameState.mech_died.connect(_on_died)
	GameState.wave_cleared.connect(_on_wave_cleared)
	for m in GameState.field:
		var view := _add_view(m)
		if view:
			view.position = _slot_pos(_slots[m.id])
	_show_wave(false)


func mech_count() -> int:
	return _views.size()


func enemy_count() -> int:
	return _enemy_count


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

	if _wave_shown != GameState.wave:
		_show_wave(true)
	var max_hp := GameState.wave_max_hp()
	_bar.max_value = max_hp
	_bar.value = GameState.wave_hp
	_hp_label.text = "W%d  %s/%s" % [GameState.wave + 1, Fmt.num(GameState.wave_hp), Fmt.num(max_hp)]
	_dps_label.text = "%s DPS" % Fmt.num(GameState.field_dps())
	var alive := ceili(GameState.wave_hp / max_hp * _enemies.size())
	while _enemy_count > alive:
		_pop_enemy(_enemies[_enemies.size() - _enemy_count])
		_enemy_count -= 1
	var t := Time.get_ticks_msec() / 1000.0
	for i in _enemies.size():
		var e := _enemies[i]
		if e.get_meta("flying"):
			e.offset.y = -e.texture.get_height() + roundf(sin(t * 3.0 + i) * 2.0)


func _show_wave(walk_in: bool) -> void:
	for e in _enemies:
		e.queue_free()
	_enemies.clear()
	_wave_shown = GameState.wave
	var type := Data.wave_type(GameState.wave)
	var tex: Texture2D = load("res://art/battlefield/enemy_%s.png" % type.sprite)
	var n := int(type.count)
	for i in n:
		var e := Sprite2D.new()
		e.texture = tex
		e.offset = Vector2(0, -tex.get_height())
		e.set_meta("flying", type.flying)
		var x := (ENEMY_X0 + ENEMY_X1) / 2.0 if n == 1 else lerpf(ENEMY_X0, ENEMY_X1, float(i) / (n - 1))
		var y := (AIR_Y + (i % 2) * 20.0) if type.flying else GROUND_Y - (i % 2) * 6.0
		e.position = Vector2(x, y)
		_enemy_layer.add_child(e)
		_enemies.append(e)
		if walk_in:
			e.position.x += 120.0
			e.create_tween().tween_property(e, "position:x", x, ENEMY_WALK_IN / maxf(GameState.time_scale, 1.0)) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_enemy_count = n
	if not walk_in:
		var alive := ceili(GameState.wave_hp / GameState.wave_max_hp() * n)
		for i in n - alive:
			_enemies[i].visible = false
		_enemy_count = alive


func _pop_enemy(e: Sprite2D) -> void:
	if not e.visible:
		return
	_puff(e.position + Vector2(0, -e.texture.get_height() / 2.0), 1.0, Color(1, 0.8, 0.6))
	e.visible = false


func _on_wave_cleared(_bounty: float) -> void:
	var center := Vector2((ENEMY_X0 + ENEMY_X1) / 2.0, GROUND_Y - 24.0)
	for e in _enemies:
		if e.visible:
			_puff(e.position + Vector2(0, -e.texture.get_height() / 2.0), 1.4, Color(1, 0.6, 0.3))
	_puff(center, 2.5, Color(1, 0.7, 0.3))
	_sparks(center)
	Flyers.spawn(Flyers.Kind.CREDITS, global_position + center, clampi(8 + GameState.wave, 8, 20))
	var tw := create_tween()
	for k in 4:
		tw.tween_property(self, "position:x", 3.0 if k % 2 == 0 else -3.0, 0.04)
	tw.tween_property(self, "position:x", 0.0, 0.04)
	_show_wave(true)


func _puff(pos: Vector2, size_scale: float, color: Color) -> void:
	var puff := Sprite2D.new()
	puff.texture = preload("res://art/fx/puff.png")
	puff.position = pos
	puff.modulate = color
	puff.scale = Vector2.ONE * 0.5 * size_scale
	_mechs.add_child(puff)
	var tw := puff.create_tween().set_parallel()
	tw.tween_property(puff, "scale", Vector2.ONE * 2.2 * size_scale, 0.35)
	tw.tween_property(puff, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(puff.queue_free)


func _sparks(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = preload("res://art/fx/spark.png")
	p.position = pos
	p.amount = 40
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.8
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 300)
	p.color_ramp = Gradient.new()
	p.color_ramp.set_color(0, Color(1, 0.9, 0.4))
	p.color_ramp.set_color(1, Color(0.9, 0.3, 0.1, 0))
	p.emitting = true
	_mechs.add_child(p)
	p.finished.connect(p.queue_free)


func _bar_label(align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = BAR_RECT.position + Vector2(6, 0)
	label.size = BAR_RECT.size - Vector2(12, 0)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.1))
	add_child(label)
	return label


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


func _on_income(m: MechState, credits: float) -> void:
	if credits > 0.0:
		_fly(m, Flyers.Kind.CREDITS, 1)


func _on_died(m: MechState, salvage: float) -> void:
	var view: MechView = _views.get(m.id)
	if view == null:
		return
	if salvage > 0.0:
		_fly(m, Flyers.Kind.SCRAP, 2)
	_views.erase(m.id)
	_slots.erase(m.id)
	view.pop()
