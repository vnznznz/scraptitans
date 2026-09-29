class_name DamageFx
extends Node2D

const SMOKE_STAGES := [0.75, 0.5, 0.3]
const SPARK_BELOW := 0.15

var stage := 0

var _smoke: CPUParticles2D
var _sparks: CPUParticles2D


func set_remaining(remaining: float) -> void:
	var s := 0
	for threshold: float in SMOKE_STAGES:
		if remaining < threshold:
			s += 1
	if remaining < SPARK_BELOW:
		s = 4
	if s == stage:
		return
	stage = s
	if _smoke == null:
		_smoke = _particles(preload("res://art/fx/puff.png"), Vector2.ZERO)
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
		_sparks = _particles(preload("res://art/fx/spark.png"), Vector2(2, 6))
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


func _particles(tex: Texture2D, pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = pos
	p.local_coords = false
	add_child(p)
	return p
