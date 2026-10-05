class_name SettingsOverlay
extends Control

enum Mode { SETTINGS, AUDIO, CONFIRM, CREDITS }

const VOLUMES := [["master", "MASTER"], ["ui", "UI"], ["battle", "BATTLE"], ["factory", "FACTORY"], ["ambience", "AMBIENCE"], ["music", "MUSIC"]]
const LICENSE_CHUNK := 1200
const EDGE_MARGIN := 8
const CREDITS := [
	["GAME DESIGN", ["VINZENZ SINAPIUS", "DISTCO.DE"]],
	["SOUNDS AND MUSIC", ["SUBSPACEAUDIO", "MUSIC: JUHANI JUNKALA", "SUBSPACEAUDIO.ITCH.IO", "CC BY 4.0, MIXED TO MONO", "FADED, TRIMMED, FILTERED"]],
	["FONT", ["SILKSCREEN", "JASON KOTTKE, OFL"]],
	["ENGINE", ["GODOT ENGINE, MIT", "GODOTENGINE.ORG/LICENSE"]],
]

var _mode := Mode.SETTINGS
var _title: Label
var _reset: Button
var _audio_button: Button
var _credits_button: Button
var _confirm: Button
var _close: Button
var _volumes: VBoxContainer
var _effects: HBoxContainer
var _panel: PanelContainer
var _credits: VBoxContainer
var _credits_scroll: ScrollContainer
var _licenses_button: Button
var _licenses: Control
var _pips := {}
var _effects_pips: VolumePips


class VolumePips:
	extends Control

	const SIZE := 8.0
	const GAP := 3.0

	var level := 0
	var max_level := 1
	var min_width := 0.0

	func set_levels(lv: int, mx: int) -> void:
		if lv == level and mx == max_level:
			return
		level = lv
		max_level = mx
		custom_minimum_size = Vector2(maxf(min_width, mx * (SIZE + GAP) - GAP), SIZE)
		queue_redraw()

	func _draw() -> void:
		var y := roundf((size.y - SIZE) / 2.0)
		var x0 := roundf((size.x - (max_level * (SIZE + GAP) - GAP)) / 2.0)
		for i in max_level:
			var r := Rect2(x0 + i * (SIZE + GAP), y, SIZE, SIZE)
			draw_rect(r, Pal.INK)
			draw_rect(r.grow(-1), Pal.GOLD if i < level else Pal.SLATE_D)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(Pal.INK, 0.75)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(280, 0)
	_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_panel.grow_horizontal = GROW_DIRECTION_BOTH
	_panel.grow_vertical = GROW_DIRECTION_BOTH
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	var version := Label.new()
	version.text = "BUILD " + str(ProjectSettings.get_setting("application/config/version"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.modulate = Color(1, 1, 1, 0.5)
	box.add_child(version)

	_volumes = VBoxContainer.new()
	_volumes.add_theme_constant_override("separation", 4)
	box.add_child(_volumes)
	for v: Array in VOLUMES:
		_volume_row(v[0], v[1])
	_effects_row(box)

	_credits_scroll = ScrollContainer.new()
	_credits_scroll.name = "CreditsScroll"
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_scroll.scroll_deadzone = 8
	box.add_child(_credits_scroll)
	_credits = VBoxContainer.new()
	_credits.name = "Credits"
	_credits.size_flags_horizontal = SIZE_EXPAND_FILL
	_credits.add_theme_constant_override("separation", 6)
	_credits_scroll.add_child(_credits)
	for section: Array in CREDITS:
		_credits_section(section[0], section[1])
	_licenses_button = _button(box, "LicensesButton", "OPEN SOURCE LICENSES", _open_licenses)
	resized.connect(_fit_credits)

	_audio_button = _button(box, "AudioButton", "AUDIO", func() -> void: _show(Mode.AUDIO))
	_credits_button = _button(box, "CreditsButton", "CREDITS", func() -> void: _show(Mode.CREDITS))
	_reset = _button(box, "Reset", "RESET RUN", func() -> void: _show(Mode.CONFIRM))
	_confirm = _button(box, "Confirm", "YES, RESET", Save.reset_run)
	_close = _button(box, "Close", "CLOSE", close)
	_close.set_meta(&"silent", true)


func _process(_delta: float) -> void:
	if not visible:
		return
	for key: String in _pips:
		_pips[key].set_levels(int(Sound.steps[key]), int(Data.audio.steps))
	_effects_pips.set_levels(Effects.level + 1, Effects.HIGH + 1)


func open() -> void:
	_show(Mode.SETTINGS)
	visible = true
	Sound.play(&"menu_open")


func close() -> void:
	if _mode != Mode.SETTINGS:
		_show(Mode.SETTINGS)
		Sound.play(&"click")
	else:
		visible = false
		Sound.play(&"menu_close")


func _show(mode: Mode) -> void:
	_mode = mode
	if _licenses:
		_licenses.visible = false
	_title.text = {Mode.SETTINGS: "SETTINGS", Mode.AUDIO: "AUDIO", Mode.CONFIRM: "RESET RUN?\nALL PROGRESS IS LOST", Mode.CREDITS: "CREDITS"}[mode]
	_volumes.visible = mode == Mode.AUDIO
	_effects.visible = mode == Mode.SETTINGS
	_audio_button.visible = mode == Mode.SETTINGS
	_credits_button.visible = mode == Mode.SETTINGS
	_reset.visible = mode == Mode.SETTINGS
	_credits_scroll.visible = mode == Mode.CREDITS
	_licenses_button.visible = mode == Mode.CREDITS
	_confirm.visible = mode == Mode.CONFIRM
	_close.text = {Mode.SETTINGS: "CLOSE", Mode.AUDIO: "BACK", Mode.CONFIRM: "CANCEL", Mode.CREDITS: "BACK"}[mode]
	_fit_credits()


func _fit_credits() -> void:
	if _mode != Mode.CREDITS:
		return
	_credits_scroll.custom_minimum_size.y = 0.0
	var rest := _panel.get_combined_minimum_size().y
	_credits_scroll.custom_minimum_size.y = minf(_credits.get_combined_minimum_size().y, size.y - rest - 2.0 * EDGE_MARGIN)


func _open_licenses() -> void:
	if _licenses == null:
		_build_licenses()
	(_licenses.find_child("Scroll", true, false) as ScrollContainer).scroll_vertical = 0
	_licenses.visible = true


func _build_licenses() -> void:
	_licenses = Control.new()
	_licenses.name = "Licenses"
	_licenses.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_licenses)
	var dim := ColorRect.new()
	dim.color = Color(Pal.INK, 0.75)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_licenses.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.offset_left = EDGE_MARGIN
	panel.offset_top = EDGE_MARGIN
	panel.offset_right = -EDGE_MARGIN
	panel.offset_bottom = -EDGE_MARGIN
	_licenses.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "OPEN SOURCE LICENSES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(scroll)
	var text := VBoxContainer.new()
	text.name = "Text"
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	scroll.add_child(text)
	var chunk := ""
	for paragraph in license_text().split("\n\n"):
		if not chunk.is_empty() and chunk.length() + paragraph.length() > LICENSE_CHUNK:
			_license_label(text, chunk)
			chunk = ""
		chunk += ("\n\n" if chunk else "") + paragraph
	_license_label(text, chunk)
	_button(box, "LicensesClose", "BACK", func() -> void: _licenses.visible = false)


func _license_label(parent: Control, chunk: String) -> void:
	var label := Label.new()
	label.text = chunk + "\n"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
	parent.add_child(label)


static func license_text() -> String:
	var out := PackedStringArray(["This game uses Godot Engine, available under the following license:", _reflow(Engine.get_license_text()),
			"Godot Engine includes these third-party components:"])
	for c: Dictionary in Engine.get_copyright_info():
		if c.name == "Godot Engine":
			continue
		var lines := PackedStringArray([c.name])
		for part: Dictionary in c.parts:
			for who: String in part.copyright:
				lines.append("Copyright " + who)
			lines.append("License: " + part.license)
		out.append("\n".join(lines))
	var texts := Engine.get_license_info()
	for license_name: String in texts:
		out.append("License " + license_name + ":")
		out.append(_reflow(texts[license_name]))
	return "\n\n".join(out)


static func _reflow(text: String) -> String:
	var paragraphs := PackedStringArray()
	for p in text.strip_edges().split("\n\n"):
		var lines := PackedStringArray()
		for line in p.split("\n"):
			lines.append(line.strip_edges())
		paragraphs.append(" ".join(lines))
	return "\n\n".join(paragraphs)


func _credits_section(heading: String, lines: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 0)
	_credits.add_child(section)
	var head := Label.new()
	head.text = heading
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Pal.GOLD)
	section.add_child(head)
	for line: String in lines:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", preload("res://fonts/silkscreen_condensed.tres"))
		section.add_child(label)


func _volume_row(key: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.name = "Volume_" + key
	row.add_theme_constant_override("separation", 4)
	_volumes.add_child(row)
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_label)
	for step: int in [-1, 1]:
		var b := Button.new()
		b.name = "Down" if step < 0 else "Up"
		b.text = "-" if step < 0 else "+"
		b.custom_minimum_size = Vector2(44, 44)
		b.pressed.connect(func() -> void: Sound.set_step(key, int(Sound.steps[key]) + step))
		row.add_child(b)
		if step < 0:
			var pips := VolumePips.new()
			pips.name = "Pips"
			pips.custom_minimum_size.x = 60
			row.add_child(pips)
			_pips[key] = pips


func _effects_row(box: Control) -> void:
	_effects = HBoxContainer.new()
	_effects.name = "Effects"
	_effects.add_theme_constant_override("separation", 4)
	box.add_child(_effects)
	var name_label := Label.new()
	name_label.text = "EFFECTS"
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_effects.add_child(name_label)
	for step: int in [-1, 1]:
		var b := Button.new()
		b.name = "Down" if step < 0 else "Up"
		b.text = "-" if step < 0 else "+"
		b.custom_minimum_size = Vector2(44, 44)
		b.pressed.connect(func() -> void: Effects.set_level(Effects.level + step))
		_effects.add_child(b)
		if step < 0:
			_effects_pips = VolumePips.new()
			_effects_pips.name = "Pips"
			_effects_pips.min_width = int(Data.audio.steps) * (VolumePips.SIZE + VolumePips.GAP) - VolumePips.GAP
			_effects.add_child(_effects_pips)


func _button(box: Control, node_name: String, label: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = label
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	box.add_child(b)
	return b
