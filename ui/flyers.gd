class_name Flyers
extends Control

enum Kind { CREDITS, SCRAP }

const MAX_IN_FLIGHT := 48
const SPENDS_PER_S := 6.0
const TIER_SECONDS := [2.0, 10.0]
const TEXTURES := [
	[preload("res://art/fx/disc_credits_1.png"), preload("res://art/fx/disc_credits_2.png"), preload("res://art/fx/disc_credits_3.png")],
	[preload("res://art/fx/disc_scrap_1.png"), preload("res://art/fx/disc_scrap_2.png"), preload("res://art/fx/disc_scrap_3.png")],
]

static var _instance: Flyers

@export var hud: Hud

var _last_spend := -1000


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


static func spawn(kind: Kind, from: Vector2, amount: float, count: int = 1) -> void:
	if _instance:
		_instance._spawn(kind, from, count, tier(kind, amount))


static func spend(kind: Kind, to: Vector2, amount: float) -> void:
	if _instance:
		_instance._spend(kind, to, tier(kind, amount))


static func tier(kind: Kind, amount: float) -> int:
	var rate := GameState.credits_rate if kind == Kind.CREDITS else GameState.scrap_gain_rate
	var seconds := amount / maxf(rate, 1.0)
	var t := 0
	for s: float in TIER_SECONDS:
		if seconds >= s:
			t += 1
	return t


func in_flight() -> int:
	return get_child_count()


func _spawn(kind: Kind, from: Vector2, count: int, disc_tier: int) -> void:
	var tex: Texture2D = TEXTURES[kind][disc_tier]
	var half := tex.get_size() / 2.0
	var target := hud.target(kind)
	for i in count:
		if get_child_count() >= MAX_IN_FLIGHT:
			return
		var disc := TextureRect.new()
		disc.texture = tex
		disc.mouse_filter = MOUSE_FILTER_IGNORE
		disc.position = from - half
		add_child(disc)
		var burst := from + Vector2(randf_range(-20, 20), randf_range(-36, -18))
		var tw := disc.create_tween()
		tw.tween_property(disc, "position", burst - half, 0.14 + i * 0.04) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(disc, "position", target - half, randf_range(0.35, 0.5)) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			hud.pulse(kind)
			disc.queue_free())


func _spend(kind: Kind, to: Vector2, disc_tier: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_spend < 1000.0 / SPENDS_PER_S or get_child_count() >= MAX_IN_FLIGHT:
		return
	_last_spend = now
	var tex: Texture2D = TEXTURES[kind][disc_tier]
	var half := tex.get_size() / 2.0
	var from := hud.target(kind)
	var disc := TextureRect.new()
	disc.texture = tex
	disc.mouse_filter = MOUSE_FILTER_IGNORE
	disc.position = from - half
	add_child(disc)
	hud.pulse_out(kind)
	var drop := from + Vector2(randf_range(-12, 12), randf_range(18, 30))
	var tw := disc.create_tween()
	tw.tween_property(disc, "position", drop - half, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(disc, "position", to - half, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(disc.queue_free)
