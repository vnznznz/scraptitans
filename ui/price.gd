class_name Price

const COLORS := [Pal.GOLD, Pal.STEEL_L]
const DIM := Color(1, 1, 1, 0.45)
const GAP := 4


static func setup(b: Button, kind: Flyers.Kind, row := false) -> void:
	var box := HBoxContainer.new()
	box.name = "Price"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", b.get_theme_constant("h_separation") if b.has_theme_constant_override("h_separation") else GAP)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	if b.icon:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = b.icon
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		b.icon = null
	var label := Label.new()
	label.name = "Text"
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if row:
		label.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	box.add_child(label)
	b.set_meta("kind", kind)
	b.set_meta("row", row)
	b.theme_type_variation = &"PriceRow" if row else &"PriceButton"


static func show(b: Button, value: String, affordable: bool) -> void:
	var box: HBoxContainer = b.get_node("Price")
	var label: Label = box.get_node("Text")
	label.text = value
	var c: Color = COLORS[b.get_meta("kind")]
	label.add_theme_color_override("font_color", c if affordable else c * DIM)
	var icon: TextureRect = box.get_node_or_null("Icon")
	if icon:
		icon.modulate = Color.WHITE if affordable else DIM
	var mode := b.get_draw_mode()
	box.position.y = 1.0 if mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED else 0.0
	b.disabled = not affordable
	var row: bool = b.get_meta("row", false)
	if affordable:
		b.theme_type_variation = &"LitRow" if row else &"LitButton"
	else:
		b.theme_type_variation = &"PriceRow" if row else &"PriceButton"


static func text(b: Button) -> String:
	return (b.get_node("Price/Text") as Label).text


static func color(b: Button) -> Color:
	return (b.get_node("Price/Text") as Label).get_theme_color("font_color")
