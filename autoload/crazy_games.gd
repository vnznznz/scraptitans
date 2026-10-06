extends Node

signal changed
signal store_changed

enum Backend { NONE, SDK, FAKE }

const INIT_TIMEOUT := 5.0
const AD_TIMEOUT := 10.0
const BANNER_INTERVAL := 30.0
const BANNER_SIZES: Array[Vector2i] = [Vector2i(468, 60), Vector2i(320, 50)]
const JS := """(function () {
	var sdk = window.CrazyGames.SDK;
	function code(e) { return (e && e.code) || 'other'; }
	function quiet(f) {
		try {
			var r = f();
			if (r && r.catch) { r.catch(function (e) { console.warn('sdk', e); }); }
		} catch (e) { console.warn('sdk', e); }
	}
	window.scrapCG = {
		ad: function (kind, cb) {
			try {
				sdk.ad.requestAd(kind, {
					adStarted: function () { cb('started', ''); },
					adFinished: function () { cb('finished', ''); },
					adError: function (e) { cb('error', code(e)); },
				});
			} catch (e) { cb('error', code(e)); }
		},
		watch: function (onMute, onAuth, onAdblock) {
			quiet(function () { sdk.game.addSettingsChangeListener(function (s) { onMute(!!(s && s.muteAudio)); }); });
			quiet(function () { sdk.user.addAuthListener(function () { onAuth(); }); });
			quiet(function () { return sdk.ad.hasAdblock().then(function (on) { onAdblock(!!on); }); });
		},
		muted: function () { try { return !!sdk.game.settings.muteAudio; } catch (e) { return false; } },
		game: function (name) { quiet(function () { return sdk.game[name](); }); },
		dataGet: function (key) {
			try {
				var v = sdk.data.getItem(key);
				return v === null || v === undefined ? '' : String(v);
			} catch (e) { return '!' + code(e); }
		},
		dataSet: function (key, value) {
			try { sdk.data.setItem(key, value); return ''; } catch (e) { return code(e); }
		},
		banner: function (x, y, w, h, cb) {
			var d = document.getElementById('scrap-banner');
			if (!d) {
				d = document.createElement('div');
				d.id = 'scrap-banner';
				d.style.position = 'absolute';
				d.style.zIndex = 10;
				document.body.appendChild(d);
			}
			d.style.left = x + 'px';
			d.style.top = y + 'px';
			d.style.width = w + 'px';
			d.style.height = h + 'px';
			d.style.display = 'block';
			try {
				sdk.banner.requestBanner({ id: 'scrap-banner', width: w, height: h }).catch(function (e) { cb(code(e)); });
			} catch (e) { cb(code(e)); }
		},
		bannerClear: function () {
			var d = document.getElementById('scrap-banner');
			if (d) {
				quiet(function () { sdk.banner.clearBanner('scrap-banner'); });
				d.style.display = 'none';
			}
		},
		width: function () { return window.innerWidth; },
	};
})()"""

var backend := Backend.NONE
var video_ads := false
var banners := false
var data := false
var adblock := false
var site_muted := false
var ad_open := false

var calls: Array[String] = []
var fake_ads: Array[String] = []
var fake_ad_time := 0.5
var fake_store := {}
var fake_banner := Rect2()

var _js: JavaScriptObject
var _ad_cb: JavaScriptObject
var _mute_cb: JavaScriptObject
var _auth_cb: JavaScriptObject
var _adblock_cb: JavaScriptObject
var _banner_cb: JavaScriptObject
var _pending := false
var _wait := 0.0
var _ad_playing := false
var _ad_waiting := false
var _ad_t := 0.0
var _banner_t := -INF
var _banner_on := false
var _loaded := false
var _gameplay := false
var _blocker: ColorRect

signal _ad_done(finished: bool)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_blocker = ColorRect.new()
	_blocker.name = "AdBlocker"
	_blocker.color = Color(Pal.INK, 0.7)
	_blocker.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocker.visible = false
	var label := Label.new()
	label.text = "AD"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_blocker.add_child(label)
	get_tree().root.add_child.call_deferred(_blocker)
	if OS.has_feature("web") and OS.has_feature("crazygames"):
		_pending = true
		_poll_init(0.0)


func _process(delta: float) -> void:
	if _pending:
		_poll_init(delta)
	if _ad_waiting:
		_ad_t += delta
		if _ad_t >= AD_TIMEOUT:
			_on_ad("error", "timeout")


func _poll_init(delta: float) -> void:
	_wait += delta
	var state := str(JavaScriptBridge.eval("window.scrapSdk || 'none'", true))
	if state == "ready":
		_pending = false
		_start_sdk()
	elif state == "none" or _wait >= INIT_TIMEOUT:
		_pending = false


func _start_sdk() -> void:
	JavaScriptBridge.eval(JS, true)
	_js = JavaScriptBridge.get_interface("scrapCG")
	_ad_cb = JavaScriptBridge.create_callback(func(args: Array) -> void: _on_ad(str(args[0]), str(args[1])))
	_mute_cb = JavaScriptBridge.create_callback(func(args: Array) -> void: set_site_muted(bool(args[0])))
	_auth_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: store_changed.emit())
	_adblock_cb = JavaScriptBridge.create_callback(func(args: Array) -> void: set_adblock(bool(args[0])))
	_banner_cb = JavaScriptBridge.create_callback(func(args: Array) -> void: _on_banner_error(str(args[0])))
	backend = Backend.SDK
	video_ads = true
	banners = true
	data = true
	site_muted = bool(_js.muted())
	_js.watch(_mute_cb, _auth_cb, _adblock_cb)
	changed.emit()
	store_changed.emit()


func use_fake() -> void:
	backend = Backend.FAKE
	video_ads = true
	banners = true
	data = true
	adblock = false
	site_muted = false
	calls = []
	fake_ads = []
	fake_store = {}
	fake_banner = Rect2()
	_banner_t = -INF
	_loaded = false
	_gameplay = false
	changed.emit()


func use_none() -> void:
	backend = Backend.NONE
	video_ads = false
	banners = false
	data = false
	adblock = false
	site_muted = false
	changed.emit()


func set_site_muted(on: bool) -> void:
	site_muted = on
	changed.emit()


func set_adblock(on: bool) -> void:
	adblock = on
	if on:
		video_ads = false
	changed.emit()


func request_ad(kind: String) -> bool:
	if not video_ads or ad_open:
		return false
	ad_open = true
	_ad_waiting = true
	_ad_t = 0.0
	_block(true)
	banner_clear()
	_note("ad " + kind)
	if backend == Backend.SDK:
		_js.ad(kind, _ad_cb)
	else:
		_fake_ad()
	var finished: bool = await _ad_done
	return finished


func _fake_ad() -> void:
	var result: String = fake_ads.pop_front() if not fake_ads.is_empty() else "finished"
	if result == "timeout":
		return
	await get_tree().process_frame
	if result != "finished":
		_on_ad("error", result)
		return
	_on_ad("started")
	await get_tree().create_timer(fake_ad_time, true, false, true).timeout
	_on_ad("finished")


func _on_ad(event: String, code := "") -> void:
	_note("ad %s %s" % [event, code])
	_ad_waiting = false
	if event == "started":
		_set_ad_playing(true)
		return
	_set_ad_playing(false)
	if event == "error":
		push_warning("CrazyGames ad: %s" % code)
		match code:
			"adsDisabledBasicLaunch":
				video_ads = false
				changed.emit()
			"adblock":
				set_adblock(true)
	if ad_open:
		ad_open = false
		_block(false)
		_ad_done.emit(event == "finished")


func _set_ad_playing(on: bool) -> void:
	_ad_playing = on
	_block(on or ad_open)
	get_tree().paused = on
	Sound.ad_mute(on)


func _block(on: bool) -> void:
	_blocker.visible = on
	if on:
		_blocker.move_to_front()


func loading_stop() -> void:
	if not _loaded:
		_loaded = true
		_game("loadingStop")


func gameplay(on: bool) -> void:
	if on != _gameplay:
		_gameplay = on
		_game("gameplayStart" if on else "gameplayStop")


func happytime() -> void:
	_game("happytime")


func _game(event: String) -> void:
	_note(event)
	if backend == Backend.SDK:
		_js.game(event)


func data_get(key: String) -> String:
	if not data:
		return ""
	if backend == Backend.FAKE:
		return fake_store.get(key, "")
	var value := str(_js.dataGet(key))
	if value.begins_with("!"):
		_data_error(value.substr(1))
		return ""
	return value


func data_set(key: String, value: String) -> void:
	if not data:
		return
	if backend == Backend.FAKE:
		fake_store[key] = value
		return
	var code := str(_js.dataSet(key, value))
	if not code.is_empty():
		_data_error(code)


func _data_error(code: String) -> void:
	push_warning("CrazyGames data: %s" % code)
	data = false
	changed.emit()


func css_per_pixel() -> float:
	if backend == Backend.SDK:
		return float(_js.width()) / get_window().size.x
	return 1.0


func banner_due() -> bool:
	return banners and not ad_open and _now() - _banner_t >= BANNER_INTERVAL


func banner_show(css: Rect2) -> void:
	_banner_t = _now()
	_banner_on = true
	_note("banner %dx%d" % [css.size.x, css.size.y])
	if backend == Backend.SDK:
		_js.banner(css.position.x, css.position.y, css.size.x, css.size.y, _banner_cb)
	else:
		fake_banner = css


func banner_clear() -> void:
	if not _banner_on:
		return
	_banner_on = false
	_note("banner clear")
	if backend == Backend.SDK:
		_js.bannerClear()
	else:
		fake_banner = Rect2()


func _on_banner_error(code: String) -> void:
	push_warning("CrazyGames banner: %s" % code)
	if code in ["bannersDisabledBasicLaunch", "bannersDisabledMobileApp"]:
		banners = false
		banner_clear()
		changed.emit()


func _note(what: String) -> void:
	if backend == Backend.FAKE:
		calls.append(what.strip_edges())


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
