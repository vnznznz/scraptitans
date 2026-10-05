class_name Flyers
extends Control

enum Kind { CREDITS, SCRAP }

const MAX_IN_FLIGHT := 48
const PAY_Z := 2
const SPENDS_PER_S := 6.0
const TIER_SECONDS := [2.0, 10.0]
const QUIET_RATE := 30.0
const QUIET_PER_S := 5.0
const QUIET_ALPHA := 0.35
const TEXTURES := [
	[preload("res://art/fx/disc_credits_1.png"), preload("res://art/fx/disc_credits_2.png"), preload("res://art/fx/disc_credits_3.png")],
	[preload("res://art/fx/disc_scrap_1.png"), preload("res://art/fx/disc_scrap_2.png"), preload("res://art/fx/disc_scrap_3.png")],
]
const SMALL := [
	preload("res://art/fx/disc_credits_1_s.png"),
	preload("res://art/fx/disc_scrap_1_s.png"),
]

static var _instance: Flyers

@export var hud: Hud

var clip := Rect2()
var _last_spend := -1000
var _last_quiet := -1000


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


static func spawn(kind: Kind, from: Vector2, amount: float, count: int = 1, loud := false) -> void:
	if _instance:
		_instance._spawn(kind, from, count, tier(kind, amount), loud)


static func spend(kind: Kind, to: Vector2, amount: float) -> void:
	if _instance:
		_instance._spend(kind, to, tier(kind, amount))


static func pay(kind: Kind, target: Control, amount: float) -> void:
	if _instance and amount > 0.0:
		var count := clampi(1 + int(log(maxf(amount / GameState.war_scale(), 1.0)) / log(10.0)), 1, 8)
		_instance._fly_out(kind, target.get_global_rect().get_center(), tier(kind, amount), count, PAY_Z)


static func tier(kind: Kind, amount: float) -> int:
	var rate := GameState.credits_rate if kind == Kind.CREDITS else GameState.scrap_gain_rate
	var seconds := amount / maxf(rate, GameState.war_scale() if kind == Kind.CREDITS else GameState.pile_scale())
	var t := 0
	for s: float in TIER_SECONDS:
		if seconds >= s:
			t += 1
	return t


func in_flight() -> int:
	return get_child_count()


func _spawn(kind: Kind, from: Vector2, count: int, disc_tier: int, loud: bool) -> void:
	var tex: Texture2D = TEXTURES[kind][disc_tier]
	var quiet := not loud and kind == Kind.SCRAP and disc_tier == 0 and GameState.scrap_gain_rate >= QUIET_RATE * GameState.pile_scale()
	if quiet:
		var now := Time.get_ticks_msec()
		if now - _last_quiet < 1000.0 / QUIET_PER_S:
			return
		_last_quiet = now
		count = 1
		tex = SMALL[kind]
	var half := tex.get_size() / 2.0
	var target := hud.target(kind)
	if clip.has_area():
		from = from.clamp(clip.position + half, clip.end - half)
	for i in count:
		if get_child_count() >= MAX_IN_FLIGHT:
			return
		var disc := TextureRect.new()
		disc.texture = tex
		disc.mouse_filter = MOUSE_FILTER_IGNORE
		disc.position = from - half
		add_child(disc)
		var burst := from + Vector2(randf_range(-20, 20), randf_range(-36, -18))
		var bend := Vector2(lerpf(burst.x, target.x, 0.3) + randf_range(-30, 30), minf(burst.y, target.y + 60.0))
		var fly := randf_range(0.4, 0.55)
		var tw := disc.create_tween()
		tw.tween_property(disc, "position", burst - half, 0.14 + i * 0.04) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(k: float) -> void:
			disc.position = (burst.lerp(bend, k).lerp(bend.lerp(target, k), k) - half).round(), 0.0, 1.0, fly) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if quiet:
			tw.parallel().tween_property(disc, "modulate:a", QUIET_ALPHA, fly)
		tw.tween_callback(func() -> void:
			if not quiet:
				hud.pulse(kind)
				if kind == Kind.CREDITS:
					Sound.play(&"coin_big" if disc_tier == TIER_SECONDS.size() else &"coin")
			disc.queue_free())


func _spend(kind: Kind, to: Vector2, disc_tier: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_spend < 1000.0 / SPENDS_PER_S:
		return
	_last_spend = now
	_fly_out(kind, to, disc_tier, 1)


func _fly_out(kind: Kind, to: Vector2, disc_tier: int, count: int, z := 0) -> void:
	var tex: Texture2D = TEXTURES[kind][disc_tier]
	var half := tex.get_size() / 2.0
	var from := hud.target(kind)
	hud.pulse_out(kind)
	for i in count:
		if get_child_count() >= MAX_IN_FLIGHT:
			return
		var disc := TextureRect.new()
		disc.texture = tex
		disc.mouse_filter = MOUSE_FILTER_IGNORE
		disc.position = from - half
		disc.visible = i == 0
		disc.z_index = z
		add_child(disc)
		var drop := from + Vector2(randf_range(-12, 12), randf_range(18, 30))
		var tw := disc.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_callback(disc.show)
		tw.tween_property(disc, "position", drop - half, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(disc, "position", to - half + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.32) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(disc.queue_free)
