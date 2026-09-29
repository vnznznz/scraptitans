extends Control

@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: VBoxContainer = %Content
@onready var _settings: SettingsOverlay = %Settings
@onready var _menu: UpgradeMenu = %UpgradeMenu
@onready var _upgrades: Button = %Upgrades

var _unlock: Button


func _ready() -> void:
	_unlock = Button.new()
	_unlock.name = "UnlockLine"
	_unlock.icon = preload("res://art/ui/credits.png")
	_unlock.custom_minimum_size = Vector2(300, 40)
	_unlock.size_flags_horizontal = SIZE_SHRINK_CENTER
	_unlock.mouse_filter = MOUSE_FILTER_PASS
	_unlock.pressed.connect(func() -> void: GameState.buy_upgrade("lines"))
	_content.add_child(_unlock)
	_content.move_child(_unlock, 0)
	for i in GameState.lines.size():
		_add_line(i)
	GameState.line_added.connect(_add_line)
	%Hud.settings_pressed.connect(_settings.open)
	_upgrades.pressed.connect(_toggle_menu)
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _process(_delta: float) -> void:
	_upgrades.text = "CLOSE" if _menu.visible else "UPGRADES"
	_unlock.visible = not GameState.upgrade_maxed("lines")
	if _unlock.visible:
		var cost := GameState.upgrade_cost("lines")
		_unlock.text = "+ UNLOCK LINE %d  %s" % [GameState.lines.size() + 1, Fmt.num(cost)]
		_unlock.disabled = GameState.credits < cost


func line_view(i: int) -> LineView:
	return _content.get_node("Line%d" % i)


func _add_line(i: int) -> void:
	var v := LineView.new()
	v.name = "Line%d" % i
	v.line_index = i
	_content.add_child(v)
	_content.move_child(v, i)


func _toggle_menu() -> void:
	if _menu.visible:
		_menu.close()
	else:
		_menu.open()
