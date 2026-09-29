class_name MechView
extends Node2D

const WALK_FPS := 8.0
const MUZZLE := Vector2(12, -16)
const SMOKE_STAGES := [0.75, 0.5, 0.3]
const SPARK_BELOW := 0.15

var walking := false

var _sprites := {}
var _shown := {}
var _walk_t := 0.0
var _smoke: CPUParticles2D
var _sparks: CPUParticles2D
var _stage := 0
var _muzzle: Sprite2D


func _process(delta: float) -> void:
	var frame: Sprite2D = _sprites.get("frame")
	if frame == null:
		return
	if walking:
		_walk_t += delta * maxf(GameState.time_scale, 1.0)
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
	var types := Data.line_slots().duplicate()
	types.sort_custom(func(a: String, b: String) -> bool:
		return Data.segment_type(a).layer < Data.segment_type(b).layer)
	for type_id: String in types:
		var sprite: Sprite2D = _sprites.get(type_id)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.offset = Vector2(0, -16)
			if type_id == "frame":
				sprite.hframes = 4
			add_child(sprite)
			_sprites[type_id] = sprite
		sprite.visible = parts.has(type_id)
		if sprite.visible:
			sprite.texture = load("res://art/mech/%s_%d.png" % [type_id, parts[type_id] + 1])


func set_damage(remaining: float) -> void:
	var stage := 0
	for threshold: float in SMOKE_STAGES:
		if remaining < threshold:
			stage += 1
	if remaining < SPARK_BELOW:
		stage = 4
	if stage == _stage:
		return
	_stage = stage
	if _smoke == null:
		_smoke = _particles(preload("res://art/fx/puff.png"), Vector2(0, -20))
		_smoke.direction = Vector2.UP
		_smoke.spread = 20.0
		_smoke.gravity = Vector2(-20, -10)
		_smoke.initial_velocity_min = 8.0
		_smoke.initial_velocity_max = 16.0
		_smoke.lifetime = 1.2
		_smoke.scale_amount_min = 0.2
		_smoke.scale_amount_max = 0.45
	_smoke.emitting = stage > 0
	if stage > 0:
		_smoke.amount = [0, 3, 6, 10, 12][stage]
		var shade: float = [1.0, 0.8, 0.55, 0.35, 0.25][stage]
		_smoke.color = Color(shade, shade, shade, 0.7)
	if stage == 4 and _sparks == null:
		_sparks = _particles(preload("res://art/fx/spark.png"), Vector2(2, -14))
		_sparks.amount = 6
		_sparks.lifetime = 0.35
		_sparks.spread = 180.0
		_sparks.gravity = Vector2(0, 200)
		_sparks.initial_velocity_min = 20.0
		_sparks.initial_velocity_max = 50.0
		_sparks.scale_amount_min = 0.5
		_sparks.scale_amount_max = 0.8
		_sparks.color = Color(1, 0.85, 0.3)
		_sparks.emitting = true


func fire(target: Vector2) -> void:
	if _muzzle == null:
		_muzzle = Sprite2D.new()
		_muzzle.texture = preload("res://art/fx/muzzle.png")
		_muzzle.position = MUZZLE + Vector2(3, 0)
		add_child(_muzzle)
	_muzzle.visible = true
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(_muzzle):
			_muzzle.visible = false)
	var bullet := Sprite2D.new()
	bullet.texture = preload("res://art/fx/bullet.png")
	bullet.position = position + MUZZLE
	bullet.rotation = (target - bullet.position).angle()
	get_parent().add_child(bullet)
	var tw := bullet.create_tween()
	tw.tween_property(bullet, "position", target, bullet.position.distance_to(target) / 400.0)
	tw.tween_callback(bullet.queue_free)


func hit() -> void:
	modulate = Color(3, 3, 3)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)


func pop() -> void:
	var parent := get_parent()
	var puff := Sprite2D.new()
	puff.texture = preload("res://art/fx/puff.png")
	puff.position = position + Vector2(0, -14)
	puff.scale = Vector2(0.5, 0.5)
	puff.modulate = Color(1, 0.7, 0.35)
	parent.add_child(puff)
	var tw := puff.create_tween().set_parallel()
	tw.tween_property(puff, "scale", Vector2(2.4, 2.4), 0.35)
	tw.tween_property(puff, "modulate", Color(0.4, 0.4, 0.4, 0.0), 0.35)
	tw.chain().tween_callback(puff.queue_free)
	var debris := CPUParticles2D.new()
	debris.texture = preload("res://art/fx/debris.png")
	debris.position = position + Vector2(0, -12)
	debris.amount = 8
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.lifetime = 0.6
	debris.direction = Vector2.UP
	debris.spread = 70.0
	debris.initial_velocity_min = 50.0
	debris.initial_velocity_max = 110.0
	debris.gravity = Vector2(0, 400)
	debris.angular_velocity_min = -400.0
	debris.angular_velocity_max = 400.0
	debris.emitting = true
	parent.add_child(debris)
	debris.finished.connect(debris.queue_free)
	queue_free()


func _particles(tex: Texture2D, pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = pos
	p.local_coords = false
	add_child(p)
	return p
