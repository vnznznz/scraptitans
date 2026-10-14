class_name Hold
extends RefCounted

const FIRST := 0.4
const EVERY := 0.15

var first := FIRST
var every := EVERY

var _t := 0.0
var _fired := false


func _init(first_delay := FIRST, interval := EVERY) -> void:
	first = first_delay
	every = interval


func step(held: bool, delta: float) -> bool:
	if not held:
		_t = 0.0
		_fired = false
		return false
	_t += delta
	if _t < (every if _fired else first):
		return false
	_t = 0.0
	_fired = true
	return true
