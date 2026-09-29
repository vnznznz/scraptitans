class_name Floater
extends Label

const GOLD := Color(1.0, 0.83, 0.3)
const GREY := Color(0.8, 0.8, 0.8)
const RISE := 18.0
const DURATION := 1.2

static var _settings := {}


static func spawn(parent: Node, at: Vector2, value: String, color: Color) -> Floater:
	var f := Floater.new()
	f.text = value
	f.label_settings = _settings_for(color)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(f)
	f.size = f.get_minimum_size()
	f.position = at - Vector2(f.size.x / 2.0, f.size.y)
	var tw := f.create_tween().set_parallel()
	tw.tween_property(f, "position:y", f.position.y - RISE, DURATION)
	tw.tween_property(f, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(f.queue_free)
	return f


static func _settings_for(color: Color) -> LabelSettings:
	if not _settings.has(color):
		var s := LabelSettings.new()
		s.font_color = color
		s.font_size = 8
		s.outline_size = 3
		s.outline_color = Color(0.08, 0.07, 0.1)
		_settings[color] = s
	return _settings[color]
