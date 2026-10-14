class_name Price

const COLORS := [Pal.GOLD, Pal.STEEL_L]
const ICONS := [preload("res://art/ui/credits.png"), preload("res://art/ui/scrap.png")]
const ICONS_SMALL := [preload("res://art/ui/credits_s.png"), preload("res://art/ui/scrap_s.png")]
const ON := Pal.WHITE
const OFF := Pal.STEEL
const DIM := Color(1, 1, 1, 0.45)
const FILL := Pal.SLATE
const FILL_INSET := Vector2(1, 2)
const GAP := 4
const ROW_GAP := 2
const LEAD_GAP := 6


static func setup(b: Button, kind: Flyers.Kind, row := false, lead_text := false) -> void:
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = FILL
	fill.visible = false
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(fill)
	var box := HBoxContainer.new()
	box.name = "Price"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", b.get_theme_constant("h_separation") if b.has_theme_constant_override("h_separation") else LEAD_GAP)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	if b.icon:
		var lead := TextureRect.new()
		lead.name = "Lead"
		lead.texture = b.icon
		lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lead)
		b.icon = null
	if lead_text:
		var lead := Label.new()
		lead.name = "LeadText"
		lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if row:
			lead.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
		box.add_child(lead)
	var cost := HBoxContainer.new()
	cost.name = "Cost"
	cost.add_theme_constant_override("separation", ROW_GAP if row else GAP)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cost)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = ICONS_SMALL[kind] if row else ICONS[kind]
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_child(icon)
	var label := Label.new()
	label.name = "Text"
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if row:
		label.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	cost.add_child(label)
	b.set_meta("row", row)
	b.theme_type_variation = &"PriceRow" if row else &"PriceButton"


static func show(b: Button, value: String, affordable: bool, lead := "", share := -1.0) -> void:
	var box: HBoxContainer = b.get_node("Price")
	var fill: ColorRect = b.get_node("Fill")
	fill.visible = not affordable and share >= 0.0
	if fill.visible:
		fill.position = FILL_INSET
		fill.size = Vector2((b.size.x - 2.0 * FILL_INSET.x) * clampf(share, 0.0, 1.0), b.size.y - 2.0 * FILL_INSET.y)
	var color := ON if affordable else OFF
	var label: Label = box.get_node("Cost/Text")
	label.text = value
	label.add_theme_color_override("font_color", color)
	(box.get_node("Cost/Icon") as TextureRect).modulate = Color.WHITE if affordable else DIM
	var lead_icon: TextureRect = box.get_node_or_null("Lead")
	var lead_label: Label = box.get_node_or_null("LeadText")
	if lead_label:
		lead_label.text = lead
		lead_label.visible = not lead.is_empty()
		lead_label.add_theme_color_override("font_color", color)
	if lead_icon:
		lead_icon.modulate = Color.WHITE if affordable else DIM
		lead_icon.visible = lead_label == null or lead.is_empty()
	var mode := b.get_draw_mode()
	box.position.y = 1.0 if mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED else 0.0
	b.disabled = not affordable
	var row: bool = b.get_meta("row", false)
	if affordable:
		b.theme_type_variation = &"LitRow" if row else &"LitButton"
	else:
		b.theme_type_variation = &"PriceRow" if row else &"PriceButton"


static func text(b: Button) -> String:
	return (b.get_node("Price/Cost/Text") as Label).text


static func color(b: Button) -> Color:
	return (b.get_node("Price/Cost/Text") as Label).get_theme_color("font_color")
