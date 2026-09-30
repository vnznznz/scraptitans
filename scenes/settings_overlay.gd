class_name SettingsOverlay
extends Control

enum Mode { SETTINGS, CONFIRM, CREDITS }

const VOLUMES := [["music", "MUSIC"], ["sfx", "SOUNDS"], ["ambience", "AMBIENCE"]]
const CREDITS := [
	["GAME DESIGN", ["VINZENZ SINAPIUS", "DISTCO.DE"]],
	["SOUNDS AND MUSIC", ["SUBSPACEAUDIO", "MUSIC: JUHANI JUNKALA", "SUBSPACEAUDIO.ITCH.IO", "CC BY 4.0, MIXED TO MONO"]],
	["FONT", ["SILKSCREEN", "JASON KOTTKE, OFL"]],
	["ENGINE", ["GODOT ENGINE, MIT", "GODOTENGINE.ORG/LICENSE"]],
]

var _mode := Mode.SETTINGS
var _title: Label
var _reset: Button
var _credits_button: Button
var _confirm: Button
var _close: Button
var _volumes: VBoxContainer
var _credits: VBoxContainer
var _pips := {}


class VolumePips:
	extends Control

	const SIZE := 8.0
	const GAP := 3.0

	var level := 0
	var max_level := 1

	func set_levels(lv: int, mx: int) -> void:
		if lv == level and mx == max_level:
			return
		level = lv
		max_level = mx
		custom_minimum_size = Vector2(mx * (SIZE + GAP) - GAP, SIZE)
		queue_redraw()

	func _draw() -> void:
		var y := roundf((size.y - SIZE) / 2.0)
		var x0 := roundf((size.x - custom_minimum_size.x) / 2.0)
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

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

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

	_credits = VBoxContainer.new()
	_credits.name = "Credits"
	_credits.add_theme_constant_override("separation", 6)
	box.add_child(_credits)
	for section: Array in CREDITS:
		_credits_section(section[0], section[1])

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
	_title.text = {Mode.SETTINGS: "SETTINGS", Mode.CONFIRM: "RESET RUN?\nALL PROGRESS IS LOST", Mode.CREDITS: "CREDITS"}[mode]
	_volumes.visible = mode == Mode.SETTINGS
	_credits_button.visible = mode == Mode.SETTINGS
	_reset.visible = mode == Mode.SETTINGS
	_credits.visible = mode == Mode.CREDITS
	_confirm.visible = mode == Mode.CONFIRM
	_close.text = {Mode.SETTINGS: "CLOSE", Mode.CONFIRM: "CANCEL", Mode.CREDITS: "BACK"}[mode]


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


func _button(box: Control, node_name: String, label: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = label
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	box.add_child(b)
	return b
