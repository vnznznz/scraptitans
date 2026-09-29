extends Node

const PATH := "user://save.json"
const VERSION := 1
const INTERVAL := 5.0

var _t := 0.0
var _requested := false


func _ready() -> void:
	if not load_game():
		GameState.new_game()
	GameState.purchased.connect(request_save)


func _process(delta: float) -> void:
	_t += delta
	if _requested or _t >= INTERVAL:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func request_save() -> void:
	_requested = true


func save_game() -> void:
	_t = 0.0
	_requested = false
	var d := GameState.to_dict()
	d.version = VERSION
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(d, "", false, true))


func load_game() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary or int(d.get("version", 0)) != VERSION:
		return false
	GameState.from_dict(d)
	return true


func reset_run() -> void:
	GameState.new_game()
	save_game()
	get_tree().reload_current_scene.call_deferred()
