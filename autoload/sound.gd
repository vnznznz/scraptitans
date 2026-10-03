extends Node

const POOL := 16
const SILENT_DB := -80.0
const BUSES := {"master": &"Master", "ui": &"UI", "battle": &"Battle", "factory": &"Factory", "ambience": &"Ambience", "music": &"Music"}
const SFX_DIR := "res://audio/sfx/%s.wav"
const MUSIC_DIR := "res://audio/music/%s.wav"
const BED_EPS_DB := 0.3
const MUSIC_STOP_FADE := 1.0

var presence := {}
var drives := {}
var plays := {}
var muted := false
var steps := {}
var music_playing := false

var _cfg: Dictionary
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _busy_until: Array[float] = []
var _owner: Array[StringName] = []
var _group_log := {}
var _beds := {}
var _music: AudioStreamPlayer
var _music_wait := -1.0
var _music_first := true
var _music_end := 0.0
var _music_fading := false
var _music_tween: Tween
var _duck := 0.0
var _hidden := false
var _ad := false
var _js_visibility: Variant
var _off := false


func _ready() -> void:
	_cfg = Data.audio
	AudioServer.bus_count = BUSES.size()
	for i in range(1, BUSES.size()):
		AudioServer.set_bus_name(i, BUSES.values()[i])
	for id: String in _cfg.sounds:
		var c: Dictionary = _cfg.sounds[id]
		var streams: Array[AudioStream] = []
		for f: String in c.files:
			streams.append(load(SFX_DIR % f))
		_sounds[StringName(id)] = {"cfg": c, "streams": streams, "bus": BUSES[c.bus], "last": -1, "next_t": 0.0}
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		_busy_until.append(0.0)
		_owner.append(&"")
	for id: String in _cfg.beds:
		var c: Dictionary = _cfg.beds[id]
		var p := AudioStreamPlayer.new()
		p.stream = load(SFX_DIR % c.file)
		p.bus = &"Ambience"
		p.volume_db = SILENT_DB
		add_child(p)
		_beds[id] = {"cfg": c, "player": p, "gain": 0.0}
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC_DIR % _cfg.music.file)
	_music.bus = &"Music"
	add_child(_music)
	_load_settings()
	if OS.has_feature("web"):
		AudioServer.register_stream_as_sample(_music.stream)
		_js_visibility = JavaScriptBridge.create_callback(_on_visibility)
		var doc: Variant = JavaScriptBridge.get_interface("document")
		doc.addEventListener("visibilitychange", _js_visibility)
	for id: String in _beds:
		_beds[id].player.play()
	GameState.nuke_launched.connect(func(_m: MechState) -> void: stop_music())


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	_off = true
	for p: AudioStreamPlayer in find_children("*", "AudioStreamPlayer", false, false):
		p.stop()


func _process(delta: float) -> void:
	delta = minf(delta, 0.25)
	for id: String in _beds:
		_update_bed(_beds[id], delta)
	_update_music(delta)


func play(id: StringName, gain_db := 0.0) -> void:
	var s: Dictionary = _sounds.get(id, {})
	if s.is_empty():
		push_error("Unknown sound: %s" % id)
		return
	if _off:
		return
	var c: Dictionary = s.cfg
	var now := _now()
	if now < s.next_t or _voices(id, now) >= int(c.get("voices", POOL)):
		return
	var group: String = c.get("group", "")
	if group and not _group_allows(group, now):
		return
	var slot := _free_slot(now)
	if slot == -1:
		return
	var streams: Array[AudioStream] = s.streams
	var pick := randi() % streams.size()
	if streams.size() > 1 and pick == s.last:
		pick = (pick + 1) % streams.size()
	s.last = pick
	s.next_t = now + float(c.get("cooldown", 0.0))
	if group:
		_group_log[group].append(now)
	var jitter := float(c.get("pitch", 0.0))
	var p := _players[slot]
	p.stream = streams[pick]
	p.bus = s.bus
	p.pitch_scale = float(c.get("pitch_base", 1.0)) * (1.0 + randf_range(-jitter, jitter))
	p.volume_db = float(c.get("volume_db", 0.0)) + float(c.get("file_db", {}).get(c.files[pick], 0.0)) + gain_db \
			+ linear_to_db(_area_gain(c.get("area", "")))
	p.play()
	_busy_until[slot] = now + p.stream.get_length() / p.pitch_scale
	_owner[slot] = id
	plays[id] = int(plays.get(id, 0)) + 1


func play_music() -> void:
	if _off:
		return
	var m: Dictionary = _cfg.music
	_music_wait = -1.0
	_music_first = false
	music_playing = true
	_music_end = _now() + _music.stream.get_length()
	_fade_music(float(m.volume_db), float(m.fade_in), SILENT_DB)
	_music.play()
	plays[&"music"] = int(plays.get(&"music", 0)) + 1


func stop_music() -> void:
	if music_playing and not _music_fading:
		_fade_music(SILENT_DB, MUSIC_STOP_FADE)
	_music_wait = -1.0
	_music_first = true


func set_muted(on: bool) -> void:
	muted = on
	_apply()
	_save_settings()


func set_step(key: String, step: int) -> void:
	steps[key] = clampi(step, 0, int(_cfg.steps))
	_apply()
	_save_settings()


func ad_mute(on: bool) -> void:
	_ad = on
	_apply()


func visible_share(c: Control) -> float:
	var r := c.get_global_rect()
	if not c.is_visible_in_tree() or r.size.y <= 0.0:
		return 0.0
	var clip := c.get_viewport_rect()
	var n := c.get_parent()
	while n:
		if n is ScrollContainer:
			clip = clip.intersection((n as Control).get_global_rect())
		n = n.get_parent()
	return clampf(r.intersection(clip).size.y / minf(r.size.y, clip.size.y), 0.0, 1.0)


func hook_button(b: BaseButton) -> void:
	b.pressed.connect(func() -> void:
		if not b.has_meta(&"silent"):
			play(&"click"))


func _update_bed(bed: Dictionary, delta: float) -> void:
	var c: Dictionary = bed.cfg
	var target := 1.0
	if c.has("drive"):
		target = clampf(float(drives.get(c.drive, 0.0)) / float(c.full), 0.0, 1.0)
	var smooth := float(c.get("smooth", 0.0))
	bed.gain = target if smooth <= 0.0 else lerpf(bed.gain, target, 1.0 - exp(-delta / smooth))
	var gain: float = bed.gain * _area_gain(c.get("area", ""))
	var db := float(c.volume_db) + linear_to_db(gain) if gain > 0.001 else SILENT_DB
	var p: AudioStreamPlayer = bed.player
	if absf(p.volume_db - db) > BED_EPS_DB:
		p.volume_db = db


func _update_music(delta: float) -> void:
	var m: Dictionary = _cfg.music
	if music_playing and not _music_fading and _now() >= _music_end - float(m.fade_out):
		_fade_music(SILENT_DB, float(m.fade_out))
	if not music_playing and _music_wait < 0.0 and GameState.revealed() and not GameState.run_over:
		_music_wait = float(m.first_after) if _music_first else randf_range(m.gap[0], m.gap[1])
	if _music_wait >= 0.0:
		_music_wait -= delta
		if _music_wait < 0.0 and not GameState.run_over:
			play_music()
	var duck := float(m.duck_db) if music_playing else 0.0
	if not is_equal_approx(_duck, duck):
		_duck = move_toward(_duck, duck, absf(float(m.duck_db)) * delta / float(m.fade_in))
		_apply()


func _fade_music(to_db: float, time: float, from_db := NAN) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_fading = to_db <= SILENT_DB
	if not is_nan(from_db):
		_music.volume_db = from_db
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", to_db, time)
	if to_db <= SILENT_DB:
		_music_tween.tween_callback(func() -> void:
			_music.stop()
			music_playing = false)


func _area_gain(area: String) -> float:
	if area.is_empty():
		return 1.0
	var hidden := db_to_linear(float(_cfg.areas[area].hidden_db))
	return lerpf(hidden, 1.0, clampf(float(presence.get(area, 1.0)), 0.0, 1.0))


func _free_slot(now: float) -> int:
	for i in POOL:
		if _busy_until[i] <= now:
			return i
	return -1


func _voices(id: StringName, now: float) -> int:
	var n := 0
	for i in POOL:
		if _owner[i] == id and _busy_until[i] > now:
			n += 1
	return n


func _group_allows(group: String, now: float) -> bool:
	var times: Array = _group_log.get_or_add(group, [])
	while not times.is_empty() and times[0] <= now - 1.0:
		times.pop_front()
	return times.size() < int(_cfg.groups[group])


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _apply() -> void:
	for key: String in BUSES:
		var i := AudioServer.get_bus_index(BUSES[key])
		var step := int(steps[key])
		AudioServer.set_bus_mute(i, step == 0 or (key == "master" and (muted or _hidden or _ad)))
		var db := linear_to_db(pow(float(step) / float(_cfg.steps), 2.0)) if step > 0 else SILENT_DB
		AudioServer.set_bus_volume_db(i, db + float(_cfg.trim_db[key]) + (_duck if key == "ambience" else 0.0))


func _load_settings() -> void:
	var d: Dictionary = _cfg.defaults.duplicate()
	d.merge(Save.load_settings(), true)
	muted = bool(d.muted)
	for key: String in BUSES:
		steps[key] = clampi(int(d[key]), 0, int(_cfg.steps))
	_apply()


func _save_settings() -> void:
	var d := {"muted": muted}
	d.merge(steps)
	Save.store_settings(d)


func _on_visibility(_args: Array) -> void:
	var doc: Variant = JavaScriptBridge.get_interface("document")
	_hidden = bool(doc.hidden)
	_apply()
