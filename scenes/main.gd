extends Control

const BADGE_ON := Color(0.85, 0.25, 0.2)
const BADGE_OFF := Color(0.3, 0.3, 0.34)

@onready var _content: VBoxContainer = %Content
@onready var _settings: SettingsOverlay = %Settings
@onready var _menu: UpgradeMenu = %UpgradeMenu
@onready var _upgrades: Button = %Upgrades

var _unlock: Button
var _badge: Label
var _badge_style: StyleBoxFlat
var _title := ""
var _app_name: String = ProjectSettings.get_setting("application/config/name")


func _ready() -> void:
	for b: BaseButton in find_children("*", "BaseButton", true, false):
		Hover.button(b)
	get_tree().node_added.connect(_on_node_added)
	if not Hover.enabled():
		ThemeDB.get_project_theme().set_stylebox("hover", "Button", get_theme_stylebox("normal", "Button"))
	_unlock = Button.new()
	_unlock.name = "UnlockLine"
	_unlock.icon = preload("res://art/ui/credits.png")
	_unlock.custom_minimum_size = Vector2(300, 40)
	_unlock.size_flags_horizontal = SIZE_SHRINK_CENTER
	_unlock.mouse_filter = MOUSE_FILTER_PASS
	_unlock.pressed.connect(_on_unlock)
	_content.add_child(_unlock)
	_content.move_child(_unlock, 0)
	for i in GameState.lines.size():
		_add_line(i)
	GameState.line_added.connect(_add_line)
	_badge = Label.new()
	_badge.name = "Badge"
	_badge_style = StyleBoxFlat.new()
	_badge_style.border_color = Color(0.08, 0.07, 0.1)
	_badge_style.set_border_width_all(1)
	_badge_style.content_margin_left = 5
	_badge_style.content_margin_right = 5
	_badge.add_theme_stylebox_override("normal", _badge_style)
	_upgrades.add_child(_badge)
	%Hud.settings_pressed.connect(_settings.open)
	_upgrades.pressed.connect(_toggle_menu)


func _process(_delta: float) -> void:
	_upgrades.visible = GameState.revealed() and not GameState.run_over
	_upgrades.text = "CLOSE" if _menu.visible else "UPGRADES"
	var affordable := GameState.affordable_upgrades()
	_badge.visible = not _menu.visible
	_badge.text = str(affordable)
	var title := "(%d) %s" % [affordable, _app_name] if affordable > 0 and GameState.revealed() and not GameState.run_over else _app_name
	if title != _title:
		_title = title
		DisplayServer.window_set_title(title)
	_badge_style.bg_color = BADGE_ON if affordable > 0 else BADGE_OFF
	_badge.modulate.a = 1.0 if affordable > 0 else 0.6
	_badge.reset_size()
	_badge.position = Vector2(_upgrades.size.x - _badge.size.x + 4, -10)
	_unlock.visible = GameState.revealed() and not GameState.upgrade_maxed("lines") and not GameState.run_over
	if _unlock.visible:
		var cost := GameState.upgrade_cost("lines")
		_unlock.text = "+ UNLOCK LINE %d  %s" % [GameState.lines.size() + 1, Fmt.num(cost)]
		_unlock.disabled = GameState.credits < cost


func _on_unlock() -> void:
	var cost := GameState.upgrade_cost("lines")
	if GameState.buy_upgrade("lines"):
		Flyers.pay(Flyers.Kind.CREDITS, _unlock, cost)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		Hover.button(n)


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
