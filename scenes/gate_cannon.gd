class_name GateCannon
extends Node2D

const SHEET := preload("res://art/battlefield/gate_cannon.png")
const LOOKS := 4
const CELL := Vector2(26, 14)
const AT := Vector2(0, 80)
const MUZZLE: Array[Vector2] = [Vector2(19, 5), Vector2(22, 5), Vector2(24, 5), Vector2(26, 5)]
const SPEED := 700.0
const ARC := 14.0
const RECOIL := 2.0

var _gun: Sprite2D


func _ready() -> void:
	_gun = Sprite2D.new()
	_gun.name = "Gun"
	_gun.texture = SHEET
	_gun.hframes = LOOKS
	_gun.centered = false
	_gun.position = AT
	add_child(_gun)


func _process(_delta: float) -> void:
	_gun.frame = look()


static func look() -> int:
	var level := GameState.level("tap_damage")
	var top := int(Data.upgrade_row("tap_damage").max_level)
	return 0 if level <= 0 else 1 if level < top / 2 else 2 if level < top else 3


func muzzle() -> Vector2:
	return AT + MUZZLE[look()]


func fire(target: Vector2, hit: Callable) -> void:
	var shown := look()
	var from := muzzle()
	_gun.position.x = AT.x - RECOIL
	_gun.create_tween().tween_property(_gun, "position:x", AT.x, 0.12)
	var flash := Sprite2D.new()
	flash.texture = preload("res://art/fx/muzzle_big.png") if shown >= 2 else preload("res://art/fx/muzzle.png")
	flash.position = from + Vector2(3, 0)
	add_child(flash)
	flash.create_tween().tween_callback(flash.queue_free).set_delay(0.06)
	var shell := Sprite2D.new()
	shell.name = "Shell"
	shell.texture = MechView.SHOTS[shown]
	shell.position = from
	add_child(shell)
	if shown == LOOKS - 1:
		Fx.trail(shell)
	var tw := shell.create_tween()
	tw.tween_method(func(k: float) -> void:
		var p := from.lerp(target, k) - Vector2(0, ARC * 4.0 * k * (1.0 - k))
		shell.rotation = (p - shell.position).angle()
		shell.position = p, 0.0, 1.0, clampf(from.distance_to(target) / SPEED, 0.12, 0.4))
	tw.tween_callback(func() -> void:
		hit.call(shown)
		for c in shell.get_children():
			if c is CPUParticles2D:
				Fx.detach(c)
		shell.queue_free())
