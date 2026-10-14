extends Node

const URL := "https://distco.de/games/scraptitans/analytics/a.php"
const MARKS: Array[int] = [60, 180, 300, 600]

var enabled := false
var session_id := ""
var played := 0.0
var _sent := {}
var _next_mark := 0


func _ready() -> void:
	enabled = OS.has_feature("web") and OS.has_feature("template_release")
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	session_id = "%08x" % randi()
	GameState.mech_deployed.connect(func(_m: MechState) -> void:
		if GameState.run_time > 0.0:
			event("first_mech"))
	GameState.wave_cleared.connect(func(_b: float) -> void:
		if GameState.wave == 1:
			event("wave1"))
	GameState.gate_fell.connect(func() -> void: event("gate"))
	GameState.nuke_launched.connect(func(_m: MechState) -> void: event("nuke"))
	event("start")


func _input(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
		event("first_tap")


func _process(delta: float) -> void:
	played += delta
	if _next_mark < MARKS.size() and played >= MARKS[_next_mark]:
		event("min%d" % (MARKS[_next_mark] / 60))
		_next_mark += 1


func event(ev: String) -> void:
	if not enabled or _sent.has(ev):
		return
	_sent[ev] = true
	var src := "cg" if OS.has_feature("crazygames") else "web"
	var dev := "mobile" if DisplayServer.is_touchscreen_available() else "desktop"
	var line := "1 %s %s %s %s %d %s %.1f" % [
		session_id, SettingsOverlay.build_version(), src, dev, GameState.prestige, ev, played,
	]
	JavaScriptBridge.eval("try{navigator.sendBeacon('%s','%s')}catch(e){}" % [URL, line], true)
