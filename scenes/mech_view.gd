class_name MechView
extends Node2D

const WALK_FPS := 8.0
const CELL_H := 48.0
const NUKE_H := 88.0
const SHOTS := [
	preload("res://art/fx/shot_1.png"),
	preload("res://art/fx/shot_2.png"),
	preload("res://art/fx/shot_3.png"),
	preload("res://art/fx/shot_4.png"),
]
const SHOT_SPEED := [320.0, 280.0, 480.0, 170.0]
const BURST := 3
const BURST_GAP := 0.07
const SHOT_SOUNDS: Array[StringName] = [&"shot_pipe", &"shot_bolt", &"shot_burst", &"shot_rocket", &"shot_beam"]

static var _rig: Dictionary

var walking := false
var nuclear := false
var walk_speed := 1.0

var _sprites := {}
var _shown := {}
var _frame_tier := 0
var _walk_t := 0.0
var _damage: DamageFx
var _muzzle: Sprite2D


static func rig() -> Dictionary:
	if _rig.is_empty():
		_rig = JSON.parse_string(FileAccess.get_file_as_string("res://art/mech/rig.json"))
	return _rig


func _process(delta: float) -> void:
	var frame: Sprite2D = _sprites.get("frame")
	if frame == null:
		return
	if walking:
		_walk_t += delta * maxf(GameState.time_scale, 1.0) * walk_speed
		frame.frame = int(_walk_t * WALK_FPS) % 4
	else:
		frame.frame = 0
	var bob := 1.0 if frame.frame % 2 == 1 else 0.0
	for type_id: String in _sprites:
		if type_id != "frame":
			_sprites[type_id].position.y = -bob


func set_parts(parts: Dictionary) -> void:
	if parts == _shown:
		return
	_shown = parts.duplicate()
	_frame_tier = int(parts.get("frame", 0))
	if nuclear:
		_show_nuclear()
		return
	var types := Data.line_slots().duplicate()
	types.sort_custom(func(a: String, b: String) -> bool:
		return Data.segment_type(a).layer < Data.segment_type(b).layer)
	for type_id: String in types:
		var sprite: Sprite2D = _sprites.get(type_id)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.offset = Vector2(0, -CELL_H / 2.0)
			sprite.hframes = 4 if type_id == "frame" else 6
			add_child(sprite)
			_sprites[type_id] = sprite
		sprite.visible = parts.has(type_id)
		if sprite.visible:
			sprite.texture = load("res://art/mech/%s_%d.png" % [type_id, parts[type_id] + 1])
			if type_id != "frame":
				sprite.frame = _frame_tier


func _show_nuclear() -> void:
	for s: Sprite2D in _sprites.values():
		s.queue_free()
	_sprites.clear()
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://art/mech/nuclear.png")
	sprite.hframes = 4
	sprite.offset = Vector2(0, -NUKE_H / 2.0)
	add_child(sprite)
	move_child(sprite, 0)
	_sprites["frame"] = sprite


func muzzle() -> Vector2:
	if nuclear:
		return _vec(rig().nuke_muzzle)
	return _vec(rig().muzzle[_frame_tier][int(_shown.get("arms", 0))])


func chest() -> Vector2:
	return _vec(rig().nuke_chest) if nuclear else _vec(rig().chest[_frame_tier])


func top() -> Vector2:
	return Vector2(0, -NUKE_H) if nuclear else _vec(rig().top[_frame_tier])


static func _vec(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


func set_damage(remaining: float) -> void:
	if _damage == null:
		_damage = DamageFx.new()
		_damage.position = chest()
		add_child(_damage)
	_damage.set_remaining(remaining)


func damage_stage() -> int:
	return _damage.stage if _damage else 0


func fire(target: Vector2) -> void:
	var arms := int(_shown.get("arms", 0))
	var from := position + muzzle()
	_flash(arms)
	Sound.play(SHOT_SOUNDS[mini(arms, SHOT_SOUNDS.size() - 1)])
	match arms:
		2:
			for i in BURST:
				_shot(2, from, target + Vector2(randf_range(-4, 4), randf_range(-3, 3)), i * BURST_GAP)
		3:
			_rocket(from, target)
		4:
			_beam(from, target)
		_:
			_shot(arms, from, target, 0.0)


func _flash(arms: int) -> void:
	if _muzzle == null:
		_muzzle = Sprite2D.new()
		_muzzle.centered = false
		add_child(_muzzle)
	var tex: Texture2D = preload("res://art/fx/muzzle_big.png") if arms >= 2 else preload("res://art/fx/muzzle.png")
	_muzzle.texture = tex
	_muzzle.position = muzzle() - Vector2(1, tex.get_height() / 2.0)
	_muzzle.modulate = Pal.CYAN if arms == 4 else Color.WHITE
	_muzzle.visible = true
	var arm: Sprite2D = _sprites.get("arms")
	if arm:
		arm.position.x = -1.0
	var tw := create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void:
		_muzzle.visible = false
		if arm:
			arm.position.x = 0.0)


func _shot(kind: int, from: Vector2, target: Vector2, delay: float) -> void:
	var bullet := Sprite2D.new()
	bullet.texture = SHOTS[kind]
	bullet.position = from
	bullet.rotation = (target - from).angle()
	bullet.visible = delay <= 0.0
	get_parent().add_child(bullet)
	var tw := bullet.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(bullet.show)
	tw.tween_property(bullet, "position", target, from.distance_to(target) / SHOT_SPEED[kind])
	tw.tween_callback(func() -> void:
		Fx.hit(bullet.get_parent(), target)
		bullet.queue_free())


func _rocket(from: Vector2, target: Vector2) -> void:
	var parent := get_parent()
	var rocket := Sprite2D.new()
	rocket.texture = SHOTS[3]
	rocket.position = from
	parent.add_child(rocket)
	var trail := Fx.trail(rocket)
	var peak := from.lerp(target, 0.5) + Vector2(0, -24)
	var tw := rocket.create_tween()
	tw.tween_method(func(k: float) -> void:
		var p := from.lerp(peak, k).lerp(peak.lerp(target, k), k)
		rocket.rotation = (p - rocket.position).angle()
		rocket.position = p, 0.0, 1.0, from.distance_to(target) / SHOT_SPEED[3])
	tw.tween_callback(func() -> void:
		Sound.play(&"rocket_hit")
		Fx.explosion(parent, target)
		Fx.detach(trail)
		rocket.queue_free())


func _beam(from: Vector2, target: Vector2) -> void:
	var beam := Sprite2D.new()
	beam.texture = preload("res://art/fx/beam.png")
	beam.centered = false
	beam.offset = Vector2(0, -1)
	beam.position = from
	beam.rotation = (target - from).angle()
	beam.scale = Vector2(from.distance_to(target), 1)
	get_parent().add_child(beam)
	Fx.hit(get_parent(), target, Pal.CYAN)
	var tw := beam.create_tween()
	tw.tween_property(beam, "modulate:a", 0.0, 0.18)
	tw.tween_callback(beam.queue_free)


func step_aside(to: Vector2) -> void:
	walking = true
	var tw := create_tween()
	tw.tween_property(self, "position", to, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: walking = false)


func hit() -> void:
	modulate = Color(1.8, 1.8, 1.8)
	var shade: Color = get_meta("shade", Color.WHITE)
	create_tween().tween_property(self, "modulate", shade, 0.12)


func pop() -> void:
	Sound.play(&"mech_death")
	var parent := get_parent()
	Fx.explosion(parent, position + chest(), true)
	Fx.debris(parent, position + chest(), 8)
	queue_free()
