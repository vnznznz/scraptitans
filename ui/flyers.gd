class_name Flyers
extends Control

enum Kind { CREDITS, SCRAP }

const MAX_IN_FLIGHT := 48
const TEXTURES := [preload("res://art/fx/disc_credits.png"), preload("res://art/fx/disc_scrap.png")]

static var _instance: Flyers

@export var hud: Hud


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


static func spawn(kind: Kind, from: Vector2, count: int = 1) -> void:
	if _instance:
		_instance._spawn(kind, from, count)


func in_flight() -> int:
	return get_child_count()


func _spawn(kind: Kind, from: Vector2, count: int) -> void:
	var tex: Texture2D = TEXTURES[kind]
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
