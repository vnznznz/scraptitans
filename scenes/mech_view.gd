class_name MechView
extends Node2D

const WALK_FPS := 8.0
const MUZZLE := Vector2(12, -16)

var walking := false

var _sprites := {}
var _shown := {}
var _walk_t := 0.0
var _damage: DamageFx
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
	if _damage == null:
		_damage = DamageFx.new()
		_damage.position = Vector2(0, -20)
		add_child(_damage)
	_damage.set_remaining(remaining)


func damage_stage() -> int:
	return _damage.stage if _damage else 0


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
