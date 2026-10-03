extends Node

const LOW := 0
const HIGH := 2

var level := HIGH
var auto := true
var monitor := true

var _cfg: Dictionary
var _since := 0.0
var _window := 0.0
var _frames := 0


func _ready() -> void:
	_cfg = Data.effects
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var d := Save.load_settings()
	level = clampi(int(d.get("effects", _cfg.mobile_default if mobile else _cfg.default)), LOW, HIGH)
	auto = bool(d.get("effects_auto", true))


func value(key: String) -> float:
	return float(_cfg.levels[level][key])


func scaled(amount: int, key: String) -> int:
	return maxi(1, roundi(amount * value(key)))


func set_level(lv: int) -> void:
	level = clampi(lv, LOW, HIGH)
	auto = false
	Save.store_settings({"effects": level, "effects_auto": auto})


func _process(delta: float) -> void:
	var a: Dictionary = _cfg.auto
	if not monitor or not auto or level == LOW or not GameState.revealed():
		_since = 0.0
		_window = 0.0
		_frames = 0
		return
	_since += delta
	if _since < float(a.after) or delta * 1000.0 > float(a.ignore_ms):
		return
	sample(delta)


func sample(delta: float) -> void:
	var a: Dictionary = _cfg.auto
	_window += delta
	_frames += 1
	if _window < float(a.seconds):
		return
	if _window / _frames * 1000.0 > float(a.frame_ms):
		level -= 1
		Save.store_settings({"effects": level, "effects_auto": auto})
	_window = 0.0
	_frames = 0
