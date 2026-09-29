class_name Fx

const EXPLOSION := preload("res://art/fx/explosion.png")
const EXPLOSION_BIG := preload("res://art/fx/explosion_big.png")
const EXPLOSION_FRAMES := 6


static func explosion(parent: Node, pos: Vector2, big := false, time := 0.45) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = EXPLOSION_BIG if big else EXPLOSION
	s.hframes = EXPLOSION_FRAMES
	s.position = pos.round()
	s.flip_h = randf() < 0.5
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "frame", EXPLOSION_FRAMES - 1, time)
	tw.tween_callback(s.queue_free)
	return s


static func hit(parent: Node, pos: Vector2, color := Color.WHITE) -> void:
	var s := Sprite2D.new()
	s.texture = preload("res://art/fx/hit.png")
	s.position = pos.round()
	s.modulate = color
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.12)
	tw.tween_callback(s.queue_free)


static func puff(parent: Node, pos: Vector2, size_scale: float, color: Color) -> void:
	var s := Sprite2D.new()
	s.texture = preload("res://art/fx/puff.png")
	s.position = pos
	s.modulate = color
	s.scale = Vector2.ONE * 0.5 * size_scale
	parent.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * 2.0 * size_scale, 0.4)
	tw.tween_property(s, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(s.queue_free)


static func trail(node: Node2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = preload("res://art/fx/smoke_small.png")
	p.local_coords = false
	p.amount = 12
	p.lifetime = 0.4
	p.gravity = Vector2(0, -20)
	p.initial_velocity_max = 6.0
	p.spread = 180.0
	p.color = Color(Pal.STEEL_L, 0.8)
	p.position = Vector2(-4, 0)
	node.add_child(p)
	return p


static func detach(p: CPUParticles2D) -> void:
	var at := p.global_position
	var holder := p.get_parent().get_parent()
	p.get_parent().remove_child(p)
	holder.add_child(p)
	p.global_position = at
	p.emitting = false
	p.finished.connect(p.queue_free)


static func debris(parent: Node, pos: Vector2, amount: int, big := false) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = preload("res://art/fx/debris_big.png") if big else preload("res://art/fx/debris.png")
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 120.0
	p.gravity = Vector2(0, 400)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.emitting = true
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	return p


static func sparks(parent: Node, pos: Vector2, amount := 40) -> void:
	var p := CPUParticles2D.new()
	p.texture = preload("res://art/fx/spark.png")
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.8
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 300)
	p.color_ramp = Gradient.new()
	p.color_ramp.set_color(0, Pal.YELLOW)
	p.color_ramp.set_color(1, Color(Pal.RUST, 0.0))
	p.emitting = true
	parent.add_child(p)
	p.finished.connect(p.queue_free)
