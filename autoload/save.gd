extends Node

const PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const KEY := "save"
const VERSION := 2
const INTERVAL := 5.0

var _t := 0.0
var _requested := false


func _ready() -> void:
	if not load_game():
		GameState.new_game()
	GameState.purchased.connect(request_save)
	CrazyGames.store_changed.connect(_on_store_changed)


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
	d.saved_at = Time.get_unix_time_from_system()
	d.away_rates = GameState.away_rates()
	var text := JSON.stringify(d, "", false, true)
	CrazyGames.data_set(KEY, text)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(text)


func load_game() -> bool:
	var text := CrazyGames.data_get(KEY)
	if text.is_empty() and FileAccess.file_exists(PATH):
		text = FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		return false
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		return false
	var version := int(d.get("version", 0))
	if version == 1:
		import_v1(d)
	elif version != VERSION:
		return false
	GameState.from_dict(d)
	var rates: Array = d.get("away_rates", [])
	if d.has("saved_at") and rates.size() == 3:
		GameState.add_away(Time.get_unix_time_from_system() - float(d.saved_at), rates[0], rates[1], rates[2])
	return true


func import_v1(d: Dictionary) -> void:
	var levels: Dictionary = d.get("levels", {})
	if levels.has("tier_plating"):
		levels["tier_plate"] = levels["tier_plating"]
		levels.erase("tier_plating")
	var mechs: Array = d.get("field", []).duplicate()
	for line: Dictionary in d.get("lines", []):
		for segment: Dictionary in line.segments:
			if segment.type_id == "plating":
				segment.type_id = "plate"
			if segment.mech is Dictionary:
				mechs.append(segment.mech)
	for mech: Dictionary in mechs:
		if mech.parts.has("plating"):
			mech.parts["plate"] = mech.parts["plating"]
			mech.parts.erase("plating")


func _on_store_changed() -> void:
	if not CrazyGames.data:
		return
	if CrazyGames.data_get(KEY).is_empty():
		save_game()
	elif load_game():
		get_tree().reload_current_scene.call_deferred()


func load_settings() -> Dictionary:
	if FileAccess.file_exists(SETTINGS_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if saved is Dictionary:
			return saved
	return {}


func store_settings(changes: Dictionary) -> void:
	var d := load_settings()
	d.merge(changes, true)
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func start_again() -> void:
	GameState.prestige += 1
	reset_run()


func reset_save() -> void:
	GameState.prestige = 0
	reset_run()


func reset_run() -> void:
	Sound.stop_music()
	GameState.new_game()
	save_game()
	get_tree().reload_current_scene.call_deferred()
