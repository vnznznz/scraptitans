class_name Price

const COLORS := [Pal.GOLD, Pal.STEEL_L]
const DIM := Color(1, 1, 1, 0.45)


static func setup(b: Button, kind: Flyers.Kind, row := false) -> void:
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, COLORS[kind])
	b.add_theme_color_override("font_disabled_color", COLORS[kind] * DIM)
	b.add_theme_color_override("icon_disabled_color", DIM)
	if row:
		b.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	b.set_meta("row", row)
	b.theme_type_variation = &"PriceRow" if row else &"PriceButton"


static func show(b: Button, text: String, affordable: bool) -> void:
	b.text = text
	b.disabled = not affordable
	var row: bool = b.get_meta("row", false)
	if affordable:
		b.theme_type_variation = &"LitRow" if row else &"LitButton"
	else:
		b.theme_type_variation = &"PriceRow" if row else &"PriceButton"
