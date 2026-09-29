class_name MechView
extends Node2D

var _sprites := {}
var _shown := {}


func set_parts(parts: Dictionary) -> void:
	if parts == _shown:
		return
	_shown = parts.duplicate()
	for type_id: String in Data.line_slots():
		var sprite: Sprite2D = _sprites.get(type_id)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.offset = Vector2(0, -16)
			add_child(sprite)
			_sprites[type_id] = sprite
		sprite.visible = parts.has(type_id)
		if sprite.visible:
			sprite.texture = load("res://art/mech/%s_%d.png" % [type_id, parts[type_id] + 1])


func pop() -> void:
	var puff := Sprite2D.new()
	puff.texture = preload("res://art/fx/puff.png")
	puff.position = position + Vector2(0, -14)
	puff.scale = Vector2(0.5, 0.5)
	get_parent().add_child(puff)
	var tw := puff.create_tween().set_parallel()
	tw.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.35)
	tw.tween_property(puff, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(puff.queue_free)
	queue_free()
