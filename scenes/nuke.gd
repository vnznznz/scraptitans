class_name Nuke
extends Control

const SWEEP_TIME := 3.0

@export var battlefield: Battlefield
@export var scroll: ScrollContainer
@export var content: Control

var _flash: ColorRect
var _band: ColorRect
var _card: PanelContainer
var _stats: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_flash)

	_band = ColorRect.new()
	_band.color = Color(1.0, 0.85, 0.6, 0.85)
	_band.size = Vector2(0, 10)
	_band.visible = false
	_band.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_band)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.custom_minimum_size = Vector2(280, 0)
	_card.set_anchors_and_offsets_preset(PRESET_CENTER)
	_card.grow_horizontal = GROW_DIRECTION_BOTH
	_card.grow_vertical = GROW_DIRECTION_BOTH
	_card.visible = false
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	var title := Label.new()
	title.text = "RUN OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	box.add_child(title)
	_stats = Label.new()
	_stats.name = "Stats"
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats)
	var again := Button.new()
	again.name = "StartAgain"
	again.text = "START AGAIN"
	again.custom_minimum_size = Vector2(0, 44)
	again.pressed.connect(Save.reset_run)
	box.add_child(again)

	GameState.nuke_launched.connect(_play)
	if GameState.run_over:
		_collapse_all()
		_show_card()


func card_visible() -> bool:
	return _card.visible


func _play(m: MechState) -> void:
	visible = true
	get_tree().call_group("upgrade_menu", "close")
	await battlefield.fire_missile(m.id)
	await get_tree().create_timer(0.3).timeout
	_flash.color = Color.WHITE
	battlefield.mushroom()
	create_tween().tween_property(_flash, "color:a", 0.0, 1.2)
	await get_tree().create_timer(1.6).timeout
	await _sweep()
	await get_tree().create_timer(0.6).timeout
	_show_card()


func _sweep() -> void:
	scroll.scroll_vertical = 0
	_band.visible = true
	_band.size.x = size.x
	var targets := content.get_children().filter(func(c: Node) -> bool: return c is Control and c.visible)
	var total := content.size.y
	var tw := create_tween()
	tw.tween_method(func(p: float) -> void:
		var y := p * total
		scroll.scroll_vertical = int(y - scroll.size.y / 2.0)
		_band.position.y = scroll.global_position.y + y - scroll.scroll_vertical - _band.size.y / 2.0
		for c: Control in targets.duplicate():
			if y >= c.position.y + c.size.y / 2.0:
				targets.erase(c)
				_collapse(c)
				battlefield.shake(2.0, 2), 0.0, 1.0, SWEEP_TIME)
	await tw.finished
	_band.visible = false


func _collapse_all() -> void:
	for c in content.get_children():
		_collapse(c)


func _collapse(c: Node) -> void:
	if c.has_method("collapse"):
		c.collapse()
	elif c is CanvasItem:
		c.visible = false


func _show_card() -> void:
	visible = true
	var t := int(GameState.run_time)
	_stats.text = "TIME %d:%02d\nMECHS %s\nCREDITS %s" % [floori(t / 60.0), t % 60, Fmt.num(GameState.mechs_built), Fmt.num(GameState.credits_earned)]
	_card.visible = true
