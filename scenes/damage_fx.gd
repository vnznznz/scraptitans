class_name DamageFx
extends Node2D

const SMOKE_STAGES := [0.4, 0.25, 0.15]
const SPARK_BELOW := 0.08
const SMOKE_AMOUNT := [0, 4, 6, 8, 10]
const SMOKE_SHADE := [1.0, 0.55, 0.42, 0.32, 0.25]

var stage := 0
var _level := -1

var _smoke: CPUParticles2D
var _sparks: CPUParticles2D
var _fire: CPUParticles2D


func set_remaining(remaining: float) -> void:
	var s := 0
	for threshold: float in SMOKE_STAGES:
		if remaining < threshold:
			s += 1
	if remaining < SPARK_BELOW:
		s = 4
	if s == stage and _level == Effects.level:
		return
	stage = s
	_level = Effects.level
	if _smoke == null:
		_smoke = _particles(preload("res://art/fx/puff.png"), Vector2.ZERO)
		_smoke.direction = Vector2.UP
		_smoke.spread = 12.0
		_smoke.gravity = Vector2(-12, -14)
		_smoke.initial_velocity_min = 14.0
		_smoke.initial_velocity_max = 24.0
		_smoke.lifetime = 1.5
		_smoke.scale_amount_min = 0.4
		_smoke.scale_amount_max = 0.7
		_smoke.color_ramp = Gradient.new()
	_smoke.emitting = stage > 0 and Effects.value("smoke") > 0.0
	if _smoke.emitting:
		_smoke.amount = Effects.scaled(SMOKE_AMOUNT[stage], "smoke")
		var shade: float = SMOKE_SHADE[stage]
		_smoke.color_ramp.set_color(0, Color(shade, shade, shade * 1.1, 0.9))
		_smoke.color_ramp.set_color(1, Color(shade, shade, shade * 1.1, 0.0))
	if stage >= 3 and _fire == null:
		_fire = _particles(preload("res://art/fx/spark.png"), Vector2(-2, 2))
		_fire.amount = 8
		_fire.lifetime = 0.4
		_fire.direction = Vector2.UP
		_fire.spread = 25.0
		_fire.gravity = Vector2(0, -40)
		_fire.initial_velocity_min = 6.0
		_fire.initial_velocity_max = 16.0
		_fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_fire.emission_rect_extents = Vector2(3, 1)
		_fire.color_ramp = Gradient.new()
		_fire.color_ramp.set_color(0, Pal.YELLOW)
		_fire.color_ramp.set_color(1, Color(Pal.RUST, 0.0))
		_fire.emitting = true
	if stage == 4 and _sparks == null:
		_sparks = _particles(preload("res://art/fx/spark.png"), Vector2(2, 6))
		_sparks.amount = 6
		_sparks.lifetime = 0.35
		_sparks.spread = 180.0
		_sparks.gravity = Vector2(0, 200)
		_sparks.initial_velocity_min = 20.0
		_sparks.initial_velocity_max = 50.0
		_sparks.color = Pal.YELLOW
		_sparks.emitting = true


func _particles(tex: Texture2D, pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = pos
	p.local_coords = false
	add_child(p)
	return p
