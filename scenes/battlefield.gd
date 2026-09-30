class_name Battlefield
extends Control

const WIDTH := 340.0
const HEIGHT := 160.0
const SKY := Pal.NAVY
const GROUND_Y := 146.0
const AIR_Y := 70.0
const ROWS := 3
const SLOTS_PER_ROW := 8
const ROW_Y := [156.0, 141.0, 126.0]
const ROW_SHADE := [1.0, 0.78, 0.6]
const FILL_ORDER := [0, 4, 2, 6, 1, 5, 3, 7]
const SLOT_X0 := 214.0
const SLOT_DX := 26.0
const WALK_SPEED := 64.0
const WALK_ANIM := 1.6
const NUKE_SPEED := 22.0
const NUKE_POS := Vector2(118, 156)
const ASIDE := Vector2(34, -5)
const ENTRY_X := -24.0
const ENEMY_X0 := 242.0
const ENEMY_X1 := 326.0
const SMOKE_Y := 28.0
const SMOKE_SPEED := 3.0
const ENEMY_WALK_IN := 1.2
const BAR_RECT := Rect2(4, 4, WIDTH - 8.0, 20)
const MECH_FIRE := Vector2(0.8, 1.6)
const ENEMY_FIRE := Vector2(1.2, 2.4)
const INCOME_DISCS_PER_S := 10.0
const MUSHROOM_FRAMES := 8
const BOUNTY_DELAY := 0.3
const ARRIVE_DELAY := 0.6
const ALARM_EVERY := 2.9

var _world: Node2D
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
var _smoke: TextureRect
var _nuke_id := -1
var _tap: TapArea
var _hint: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_bg = TextureRect.new()
	_bg.texture = preload("res://art/battlefield/bg.png")
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_world.add_child(_bg)
	_smoke = TextureRect.new()
	_smoke.texture = preload("res://art/battlefield/smoke.png")
	_smoke.stretch_mode = TextureRect.STRETCH_TILE
	_smoke.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_smoke.size = Vector2(_smoke.texture.get_width() * 2, _smoke.texture.get_height())
	_smoke.position.y = SMOKE_Y
	_smoke.mouse_filter = MOUSE_FILTER_IGNORE
	_world.add_child(_smoke)

	_tap = TapArea.new()
	_tap.name = "FieldTap"
	_tap.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tap.tapped.connect(_on_tap)
	add_child(_tap)

	_enemy_layer = Node2D.new()
	_enemy_layer.y_sort_enabled = true
	_world.add_child(_enemy_layer)
	_mechs = Node2D.new()
	_world.add_child(_mechs)
	_hint = Control.new()
	_hint.name = "HintAnchor"
	_hint.position = Vector2(ENEMY_X0, AIR_Y - 20.0)
	_hint.size = Vector2(ENEMY_X1 - ENEMY_X0, 8)
	_hint.mouse_filter = MOUSE_FILTER_IGNORE
	_world.add_child(_hint)
	resized.connect(_on_resized)
	_on_resized()

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
	GameState.enemy_killed.connect(_on_enemy_killed)
	if GameState.run_over:
		scorch()
		return
	_sync_views()
	for id: int in _views:
		_views[id].position = _slot_pos(_slots[id])
	_show_wave(false)


func hint_anchor() -> Control:
	return _hint


func _on_resized() -> void:
	_world.position.y = maxf(0.0, size.y - HEIGHT)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY * _bg.modulate)


func mech_count() -> int:
	return _views.size()


func enemy_count() -> int:
	return _enemy_count


func mech_view(id: int) -> MechView:
	return _views.get(id)


func _process(delta: float) -> void:
	_smoke.position.x = -fmod(Time.get_ticks_msec() / 1000.0 * SMOKE_SPEED, _smoke.texture.get_width())
	if GameState.run_over:
		_step_views(delta, false)
		return
	_sync_views()
	_step_views(delta, true)

	if _wave_shown != GameState.wave:
		_show_wave(true)
	var max_hp := GameState.wave_max_hp()
	_bar.max_value = max_hp
	_bar.value = GameState.wave_hp
	_hp_label.text = "WAVE %d" % (GameState.wave + 1)
	_dps_label.text = "%s DMG/S" % Fmt.num(GameState.wave_dps())
	var alive := GameState.wave_alive()
	while _enemy_count > alive:
		_pop_enemy(_enemies.size() - _enemy_count)
		_enemy_count -= 1
	var t := Time.get_ticks_msec() / 1000.0
	var remaining := GameState.wave_hp / max_hp
	for i in _enemies.size():
		var e := _enemies[i]
		if e.get_meta("flying"):
			e.offset.y = -e.texture.get_height() / 2.0 + roundf(sin(t * 3.0 + i) * 2.0)
		if e.visible:
			(e.get_node("Damage") as DamageFx).set_remaining(remaining)
		if e.visible and not _views.is_empty():
			var ft: float = e.get_meta("fire_t", randf_range(0.0, ENEMY_FIRE.y)) - delta * GameState.time_scale
			if ft <= 0.0:
				ft = randf_range(ENEMY_FIRE.x, ENEMY_FIRE.y)
				_enemy_fire(e)
			e.set_meta("fire_t", ft)


func _step_views(delta: float, fight: bool) -> void:
	var speed := delta * maxf(GameState.time_scale, 1.0)
	for id: int in _views:
		var view: MechView = _views[id]
		var m: MechState = _states[id]
		view.set_damage(m.remaining())
		if _nuke_id != -1 and id != _nuke_id:
			continue
		var target := _slot_pos(_slots[id])
		view.position = view.position.move_toward(target, (NUKE_SPEED if view.nuclear else WALK_SPEED) * speed)
		view.walking = view.position != target
		if not fight or view.walking or m.dps <= 0.0:
			continue
		_fire_t[id] = float(_fire_t.get(id, randf_range(0.0, MECH_FIRE.y))) - delta * GameState.time_scale
		if _fire_t[id] <= 0.0:
			_fire_t[id] = randf_range(MECH_FIRE.x, MECH_FIRE.y)
			var target_enemy := _random_enemy()
			if target_enemy:
				var half := target_enemy.texture.get_size() / 4.0
				view.fire(_enemy_center(target_enemy) + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y)))


func _random_enemy() -> Sprite2D:
	var alive := _enemies.filter(func(e: Sprite2D) -> bool: return e.visible)
	return alive.pick_random() if alive else null


func enemy_xs() -> Array:
	return _enemies.map(func(e: Sprite2D) -> float: return e.position.x)


func _enemy_center(e: Sprite2D) -> Vector2:
	return e.position + e.offset


func _enemy_fire(e: Sprite2D) -> void:
	var id: int = _views.keys().pick_random()
	var view: MechView = _views[id]
	if view.walking:
		return
	Sound.play(StringName("enemy_shot_" + e.get_meta("sprite")))
	var bullet := Sprite2D.new()
	bullet.texture = load("res://art/fx/enemy_shot_%s.png" % e.get_meta("sprite"))
	bullet.position = _enemy_center(e) - Vector2(e.texture.get_width() / 2.0, 0)
	_mechs.add_child(bullet)
	var target := view.position + view.chest() + Vector2(randf_range(-4, 4), randf_range(-3, 3))
	bullet.rotation = (target - bullet.position).angle() + PI
	var tw := bullet.create_tween()
	tw.tween_property(bullet, "position", target, bullet.position.distance_to(target) / 260.0)
	tw.tween_callback(func() -> void:
		var hit: MechView = _views.get(id)
		if hit:
			hit.hit()
		Fx.hit(_mechs, target, Pal.PINK)
		bullet.queue_free())


func _show_wave(walk_in: bool) -> void:
	for e in _enemies:
		e.queue_free()
	_enemies.clear()
	_wave_shown = GameState.wave
	var list := GameState.wave_enemies()
	var n := list.size()
	var layer_sizes := {true: 0, false: 0}
	for en in list:
		layer_sizes[en.flying] += 1
	var layer_i := {true: 0, false: 0}
	for en in list:
		var e := Sprite2D.new()
		e.texture = load("res://art/battlefield/enemy_%s_%d.png" % [en.sprite, en.variant + 1])
		e.offset = Vector2(0, -e.texture.get_height() / 2.0)
		e.set_meta("flying", en.flying)
		e.set_meta("sprite", en.sprite)
		var i: int = layer_i[en.flying]
		var count: int = layer_sizes[en.flying]
		layer_i[en.flying] += 1
		var x := (ENEMY_X0 + ENEMY_X1) / 2.0 if count == 1 else lerpf(ENEMY_X0, ENEMY_X1, float(i) / (count - 1))
		x = minf(x, WIDTH - e.texture.get_width() / 2.0 - 2.0)
		var y := (AIR_Y + (i % 2) * 18.0) if en.flying else GROUND_Y - (i % 2) * 7.0
		e.position = Vector2(x, y)
		var fx := DamageFx.new()
		fx.name = "Damage"
		fx.position = Vector2(0, -e.texture.get_height() / 2.0)
		e.add_child(fx)
		_enemy_layer.add_child(e)
		_enemies.append(e)
		if walk_in:
			e.position.x += 120.0
			e.create_tween().tween_property(e, "position:x", x, ENEMY_WALK_IN / maxf(GameState.time_scale, 1.0)) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_enemy_count = n
	if walk_in:
		get_tree().create_timer(ARRIVE_DELAY).timeout.connect(Sound.play.bind(&"wave_arrive"))
	else:
		var alive := GameState.wave_alive()
		for i in n - alive:
			_enemies[i].visible = false
		_enemy_count = alive


func _on_tap(at: Vector2) -> void:
	if GameState.tap_wave() <= 0.0:
		return
	Sound.play(&"field_tap")
	var target: Sprite2D = null
	at -= _world.position
	for e in _enemies:
		if e.visible and (target == null or _enemy_center(e).distance_to(at) < _enemy_center(target).distance_to(at)):
			target = e
	if target:
		target.modulate = Color(3, 3, 3)
		target.create_tween().tween_property(target, "modulate", Color.WHITE, 0.12)
		var spot := _enemy_center(target) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		Fx.hit(_mechs, spot)
		Fx.puff(_mechs, spot, 0.4, Pal.YELLOW)


func _pop_enemy(i: int) -> void:
	var e := _enemies[i]
	if not e.visible:
		return
	var big := e.texture.get_height() > 30
	Sound.play(&"enemy_pop_big" if big else &"enemy_pop")
	Fx.explosion(_mechs, _enemy_center(e), big)
	Fx.debris(_mechs, _enemy_center(e), 10 if big else 5)
	e.visible = false


func _on_enemy_killed(i: int, scrap: float) -> void:
	if i < _enemies.size():
		Flyers.spawn(Flyers.Kind.SCRAP, _world.global_position + _enemy_center(_enemies[i]), scrap, 2)


func _on_wave_cleared(bounty: float) -> void:
	var center := Vector2((ENEMY_X0 + ENEMY_X1) / 2.0, GROUND_Y - 30.0)
	for e in _enemies:
		if e.visible:
			Fx.explosion(_mechs, _enemy_center(e), true, randf_range(0.4, 0.6))
	Fx.explosion(_mechs, center, true, 0.6)
	Fx.explosion(_mechs, center + Vector2(-18, 10), true, 0.5)
	Fx.puff(_mechs, center, 2.5, Pal.ORANGE)
	Fx.sparks(_mechs, center)
	Sound.play(&"wave_clear")
	get_tree().create_timer(BOUNTY_DELAY).timeout.connect(Sound.play.bind(&"bounty"))
	Flyers.spawn(Flyers.Kind.CREDITS, _world.global_position + center, bounty, clampi(8 + GameState.wave, 8, 20))
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
	var alarm_t := 0.0
	while is_instance_valid(view) and view.walking:
		alarm_t -= get_process_delta_time()
		if alarm_t <= 0.0:
			Sound.play(&"nuke_alarm")
			alarm_t = ALARM_EVERY
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	Sound.play(&"nuke_launch")
	var missile := Sprite2D.new()
	missile.texture = preload("res://art/fx/missile.png")
	var start := view.position + view.muzzle() + Vector2(0, missile.texture.get_height() / 2.0)
	missile.position = start
	_mechs.add_child(missile)
	var trail := Fx.trail(missile)
	trail.position = Vector2(0, missile.texture.get_height() / 2.0)
	trail.amount = 30
	trail.lifetime = 0.9
	Fx.explosion(_mechs, start + Vector2(0, 10), true)
	Fx.puff(_mechs, start + Vector2(-8, 16), 1.6, Pal.STEEL_L)
	Fx.puff(_mechs, start + Vector2(8, 16), 1.6, Pal.STEEL_L)
	shake(2.0, 6)
	var peak := Vector2(start.x + 70, -_world.position.y - 40)
	var tw := missile.create_tween()
	tw.tween_method(func(k: float) -> void:
		var p := start.lerp(Vector2(start.x, peak.y), k).lerp(Vector2(start.x, peak.y).lerp(peak + Vector2(300, 0), k), k)
		missile.rotation = (p - missile.position).angle() + PI / 2.0
		missile.position = p, 0.0, 1.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	missile.queue_free()


func mushroom() -> void:
	scorch()
	var cloud := Sprite2D.new()
	cloud.texture = preload("res://art/fx/mushroom.png")
	cloud.hframes = MUSHROOM_FRAMES
	cloud.offset = Vector2(0, -cloud.texture.get_height() / 2.0)
	cloud.position = Vector2(size.x / 2.0, GROUND_Y + 6)
	_world.add_child(cloud)
	var tw := cloud.create_tween()
	tw.tween_property(cloud, "frame", MUSHROOM_FRAMES - 1, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cloud, "position:y", GROUND_Y - 6, 3.0)
	for k in 6:
		Fx.explosion(_world, Vector2(randf_range(20, size.x - 20), GROUND_Y - randf_range(0, 12)), true, randf_range(0.5, 0.9))


func scorch() -> void:
	for c: Node in _mechs.get_children() + _enemy_layer.get_children():
		c.queue_free()
	_views.clear()
	_slots.clear()
	_states.clear()
	_nuke_id = -1
	_enemies.clear()
	_enemy_count = 0
	_bar.visible = false
	_hp_label.visible = false
	_dps_label.visible = false
	_bg.modulate = Color(1.2, 0.7, 0.5)
	_smoke.modulate = Color(0.4, 0.2, 0.2)
	queue_redraw()


func _bar_label(node_name: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = BAR_RECT.position + Vector2(6, 0)
	label.size = BAR_RECT.size - Vector2(12, 0)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Pal.INK)
	label.z_index = Main.TEXT_Z
	add_child(label)
	return label


func _add_view(m: MechState) -> MechView:
	var slot := -1 if m.is_nuclear() else _free_slot()
	if slot == -1 and not m.is_nuclear():
		slot = _replace_weakest(m)
		if slot == -1:
			return null
	var view := MechView.new()
	view.nuclear = m.is_nuclear()
	view.set_parts(m.parts)
	view.position = Vector2(ENTRY_X, _slot_pos(slot).y)
	view.walking = true
	view.walk_speed = 0.6 if view.nuclear else WALK_ANIM
	_mechs.add_child(view)
	_views[m.id] = view
	_states[m.id] = m
	_set_slot(m.id, slot)
	return view


func _set_slot(id: int, slot: int) -> void:
	var view: MechView = _views[id]
	var row := int(float(slot) / SLOTS_PER_ROW) if slot >= 0 else -1
	_slots[id] = slot
	var shade: float = ROW_SHADE[row] if row >= 0 else 1.0
	view.modulate = Color(shade, shade, minf(shade + 0.04, 1.0))
	view.set_meta("shade", view.modulate)
	view.set_meta("row", row)
	_mechs.move_child(view, _row_index(row))


static func score(m: MechState) -> int:
	var total := 0
	for type_id: String in m.parts:
		total += int(m.parts[type_id]) + 1
	return total


func _sync_views() -> void:
	for m in GameState.field:
		if not _views.has(m.id):
			_add_view(m)
	if _nuke_id == -1:
		_sort_rows()


func _replace_weakest(m: MechState) -> int:
	var weakest := -1
	for id: int in _views:
		if _slots[id] >= 0 and (weakest == -1 or score(_states[id]) < score(_states[weakest])):
			weakest = id
	if weakest == -1 or score(_states[weakest]) >= score(m):
		return -1
	var slot: int = _slots[weakest]
	var view: MechView = _views[weakest]
	_views.erase(weakest)
	_slots.erase(weakest)
	_states.erase(weakest)
	_fire_t.erase(weakest)
	var tw := view.create_tween()
	tw.tween_property(view, "modulate:a", 0.0, 0.3)
	tw.tween_callback(view.queue_free)
	return slot


func _sort_rows() -> void:
	var rows: Array[Array] = [[], [], []]
	for id: int in _slots:
		if _slots[id] >= 0:
			rows[int(float(_slots[id]) / SLOTS_PER_ROW)].append(id)
	for front in ROWS - 1:
		while true:
			var weak := -1
			for id: int in rows[front]:
				if weak == -1 or score(_states[id]) < score(_states[weak]):
					weak = id
			var strong := -1
			var strong_row := -1
			for r in range(front + 1, ROWS):
				for id: int in rows[r]:
					if strong == -1 or score(_states[id]) > score(_states[strong]):
						strong = id
						strong_row = r
			if weak == -1 or strong == -1 or score(_states[strong]) <= score(_states[weak]):
				break
			var slot: int = _slots[weak]
			_set_slot(weak, _slots[strong])
			_set_slot(strong, slot)
			rows[front].erase(weak)
			rows[front].append(strong)
			rows[strong_row].erase(strong)
			rows[strong_row].append(weak)


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
	if slot < 0:
		return NUKE_POS
	var row := int(float(slot) / SLOTS_PER_ROW)
	var col: int = FILL_ORDER[slot % SLOTS_PER_ROW]
	var jitter := float((slot * 37) % 7 - 3)
	return Vector2(SLOT_X0 - col * SLOT_DX - [0.0, SLOT_DX / 2.0, SLOT_DX / 4.0][row] + jitter, ROW_Y[row])


func _fly(m: MechState, kind: Flyers.Kind, amount: float, count: int) -> void:
	var view: MechView = _views.get(m.id)
	if view:
		Flyers.spawn(kind, view.global_position + view.top(), amount, count)


func _on_deployed(m: MechState) -> void:
	var view := _add_view(m)
	if m.is_nuclear():
		_nuke_id = m.id
		_clear_path()
	if view:
		_fly(m, Flyers.Kind.CREDITS, m.deploy_fee, clampi(2 + int(log(maxf(m.deploy_fee, 1.0)) / log(10.0)), 2, 6))


func _clear_path() -> void:
	for id: int in _views:
		if id == _nuke_id:
			continue
		var view: MechView = _views[id]
		var side := -1.0 if view.position.x < NUKE_POS.x else 1.0
		view.step_aside(Vector2(clampf(view.position.x + side * ASIDE.x, 12.0, ENEMY_X0 - 16.0), view.position.y + ASIDE.y))


func _on_income(m: MechState, credits: float) -> void:
	if credits <= 0.0 or randf() > INCOME_DISCS_PER_S / maxf(_views.size(), 1.0):
		return
	_fly(m, Flyers.Kind.CREDITS, credits, 1)


func _on_died(m: MechState, salvage: float) -> void:
	var view: MechView = _views.get(m.id)
	if view == null:
		return
	if salvage > 0.0:
		_fly(m, Flyers.Kind.SCRAP, salvage, 2)
	_views.erase(m.id)
	_slots.erase(m.id)
	_states.erase(m.id)
	_fire_t.erase(m.id)
	view.pop()
