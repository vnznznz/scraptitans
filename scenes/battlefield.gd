class_name Battlefield
extends Control

const GROUND_Y := 138.0
const AIR_Y := 84.0
const ROWS := 3
const SLOTS_PER_ROW := 8
const ROW_DY := 10.0
const SLOT_X0 := 214.0
const SLOT_DX := 24.0
const WALK_SPEED := 40.0
const ENTRY_X := -16.0
const ENEMY_X0 := 258.0
const ENEMY_X1 := 346.0
const ENEMY_WALK_IN := 1.2
const BAR_RECT := Rect2(4, 4, 352, 20)
const MECH_FIRE := Vector2(0.8, 1.6)
const ENEMY_FIRE := Vector2(1.2, 2.4)
const INCOME_DISCS_PER_S := 10.0

var _mechs: Node2D
var _enemy_layer: Node2D
var _enemies: Array[Sprite2D] = []
var _enemy_count := 0
var _wave_shown := -1
var _views := {}
var _states := {}
var _slots := {}
var _fire_t := {}
var _bar: TextureProgressBar
var _hp_label: Label
var _dps_label: Label
var _bg: TextureRect


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_bg = TextureRect.new()
	_bg.texture = preload("res://art/battlefield/bg.png")
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg)

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
	_hp_label = _bar_label("HpLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_dps_label = _bar_label("DpsLabel", HORIZONTAL_ALIGNMENT_RIGHT)

	GameState.mech_deployed.connect(_on_deployed)
	GameState.mech_income.connect(_on_income)
	GameState.mech_died.connect(_on_died)
	GameState.wave_cleared.connect(_on_wave_cleared)
	if GameState.run_over:
		scorch()
		return
	for m in GameState.field:
		var view := _add_view(m)
		if view:
			view.position = _slot_pos(_slots[m.id])
	_show_wave(false)


func mech_count() -> int:
	return _views.size()


func enemy_count() -> int:
	return _enemy_count


func mech_view(id: int) -> MechView:
	return _views.get(id)


func _process(delta: float) -> void:
	if GameState.run_over:
		_step_views(delta, false)
		return
	for m in GameState.field:
		if not _views.has(m.id):
			_add_view(m)
	_step_views(delta, true)

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
		if e.visible and not _views.is_empty():
			var ft: float = e.get_meta("fire_t", randf_range(0.0, ENEMY_FIRE.y)) - delta * GameState.time_scale
			if ft <= 0.0:
				ft = randf_range(ENEMY_FIRE.x, ENEMY_FIRE.y)
				_enemy_fire(e)
			e.set_meta("fire_t", ft)


func _step_views(delta: float, fight: bool) -> void:
	var step := WALK_SPEED * delta * maxf(GameState.time_scale, 1.0)
	for id: int in _views:
		var view: MechView = _views[id]
		var target := _slot_pos(_slots[id])
		view.position.x = move_toward(view.position.x, target.x, step)
		view.position.y = target.y
		view.walking = view.position.x != target.x
		var m: MechState = _states[id]
		view.set_damage(m.remaining())
		if not fight or view.walking or m.dps <= 0.0:
			continue
		_fire_t[id] = float(_fire_t.get(id, randf_range(0.0, MECH_FIRE.y))) - delta * GameState.time_scale
		if _fire_t[id] <= 0.0:
			_fire_t[id] = randf_range(MECH_FIRE.x, MECH_FIRE.y)
			var target_enemy := _random_enemy()
			if target_enemy:
				view.fire(_enemy_center(target_enemy) + Vector2(randf_range(-6, 6), randf_range(-4, 4)))


func _random_enemy() -> Sprite2D:
	var alive := _enemies.filter(func(e: Sprite2D) -> bool: return e.visible)
	return alive.pick_random() if alive else null


func _enemy_center(e: Sprite2D) -> Vector2:
	return e.position + Vector2(0, e.offset.y + e.texture.get_height() / 2.0)


func _enemy_fire(e: Sprite2D) -> void:
	var view: MechView = _views.values().pick_random()
	if view.walking:
		return
	var bullet := Sprite2D.new()
	bullet.texture = preload("res://art/fx/enemy_bullet.png")
	bullet.position = _enemy_center(e) - Vector2(e.texture.get_width() / 2.0, 0)
	_mechs.add_child(bullet)
	var target := view.position + Vector2(0, -14)
	var tw := bullet.create_tween()
	tw.tween_property(bullet, "position", target, bullet.position.distance_to(target) / 260.0)
	tw.tween_callback(func() -> void:
		if is_instance_valid(view):
			view.hit()
		bullet.queue_free())


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
	_puff(_enemy_center(e), 1.0, Color(1, 0.8, 0.6))
	e.visible = false


func _on_wave_cleared(_bounty: float) -> void:
	var center := Vector2((ENEMY_X0 + ENEMY_X1) / 2.0, GROUND_Y - 24.0)
	for e in _enemies:
		if e.visible:
			_puff(_enemy_center(e), 1.4, Color(1, 0.6, 0.3))
	_puff(center, 2.5, Color(1, 0.7, 0.3))
	_sparks(center)
	Flyers.spawn(Flyers.Kind.CREDITS, global_position + center, clampi(8 + GameState.wave, 8, 20))
	shake()
	_show_wave(true)


func shake(strength: float = 3.0, count: int = 4) -> void:
	var tw := create_tween()
	for k in count:
		tw.tween_property(self, "position:x", strength if k % 2 == 0 else -strength, 0.04)
	tw.tween_property(self, "position:x", 0.0, 0.04)


func fire_missile(id: int) -> void:
	var view: MechView = _views.get(id)
	if view == null:
		return
	while is_instance_valid(view) and view.walking:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var missile := Sprite2D.new()
	missile.texture = preload("res://art/fx/missile.png")
	var start := view.position + Vector2(-8, -20)
	missile.position = start
	_mechs.add_child(missile)
	_puff(start + Vector2(0, 8), 1.2, Color(0.8, 0.8, 0.8))
	var peak := Vector2(start.x + 90, -60)
	var tw := missile.create_tween()
	tw.tween_method(func(k: float) -> void:
		var p := start.lerp(peak, k).lerp(peak.lerp(Vector2(420, -40), k), k)
		missile.rotation = (p - missile.position).angle() + PI / 2.0
		missile.position = p, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	missile.queue_free()


func mushroom() -> void:
	scorch()
	var cloud := Sprite2D.new()
	cloud.texture = preload("res://art/fx/mushroom.png")
	cloud.offset = Vector2(0, -cloud.texture.get_height())
	cloud.position = Vector2(size.x / 2.0, GROUND_Y + 8)
	cloud.scale = Vector2(0.3, 0.1)
	add_child(cloud)
	var tw := cloud.create_tween()
	tw.tween_property(cloud, "scale", Vector2(2.0, 2.0), 1.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cloud, "modulate", Color(0.7, 0.6, 0.6), 3.0)
	shake(5.0, 12)


func scorch() -> void:
	for c: Node in _mechs.get_children() + _enemy_layer.get_children():
		c.queue_free()
	_views.clear()
	_slots.clear()
	_states.clear()
	_enemies.clear()
	_enemy_count = 0
	_bar.visible = false
	_hp_label.visible = false
	_dps_label.visible = false
	_bg.modulate = Color(1.2, 0.7, 0.5)


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


func _bar_label(node_name: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
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
	var row := int(float(slot) / SLOTS_PER_ROW)
	view.position = Vector2(ENTRY_X, _slot_pos(slot).y)
	view.walking = true
	var shade := 1.0 - row * 0.15
	view.modulate = Color(shade, shade, shade + 0.03)
	view.set_meta("row", row)
	_mechs.add_child(view)
	_mechs.move_child(view, _row_index(row))
	_views[m.id] = view
	_states[m.id] = m
	_slots[m.id] = slot
	return view


func _row_index(row: int) -> int:
	var i := 0
	for c in _mechs.get_children():
		if c is MechView and int(c.get_meta("row", 0)) > row:
			i = c.get_index() + 1
	return i


func _free_slot() -> int:
	var used := _slots.values()
	for i in SLOTS_PER_ROW * ROWS:
		if not used.has(i):
			return i
	return -1


func _slot_pos(slot: int) -> Vector2:
	var row := int(float(slot) / SLOTS_PER_ROW)
	var col := slot % SLOTS_PER_ROW
	return Vector2(SLOT_X0 - col * SLOT_DX - row * SLOT_DX / 2.0, GROUND_Y - row * ROW_DY)


func _fly(m: MechState, kind: Flyers.Kind, count: int, disc_scale: float = 1.0) -> void:
	var view: MechView = _views.get(m.id)
	if view:
		Flyers.spawn(kind, view.global_position + Vector2(0, -34), count, disc_scale)


func _on_deployed(m: MechState) -> void:
	if m.is_nuclear() and _free_slot() == -1:
		var evict: int = _slots.find_key(0)
		_views[evict].queue_free()
		_views.erase(evict)
		_slots.erase(evict)
	var view := _add_view(m)
	if view:
		_fly(m, Flyers.Kind.CREDITS, clampi(2 + int(log(maxf(m.deploy_fee, 1.0)) / log(10.0)), 2, 6))


func _on_income(m: MechState, credits: float) -> void:
	if credits <= 0.0 or randf() > INCOME_DISCS_PER_S / maxf(_views.size(), 1.0):
		return
	var average := GameState.credits_rate / maxf(GameState.field.size(), 1.0)
	_fly(m, Flyers.Kind.CREDITS, 1, 2.0 if average > 0.0 and credits >= 2.0 * average else 1.0)


func _on_died(m: MechState, salvage: float) -> void:
	var view: MechView = _views.get(m.id)
	if view == null:
		return
	if salvage > 0.0:
		_fly(m, Flyers.Kind.SCRAP, 2)
	_views.erase(m.id)
	_slots.erase(m.id)
	_states.erase(m.id)
	_fire_t.erase(m.id)
	view.pop()
