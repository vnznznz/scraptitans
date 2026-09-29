class_name Main
extends Control

const BADGE_ON := Pal.RED
const FIELD_MAX := 2.0
const UNLOCK_SMALL := Vector2(220, 32)
const UNLOCK_BIG := Vector2(300, 44)
const UNLOCK_GAP := 8.0
const FLYERS_Z := 1
const TEXT_Z := 2
const OVERLAY_Z := 3

@onready var _content: VBoxContainer = %Content
@onready var _settings: SettingsOverlay = %Settings
@onready var _menu: UpgradeMenu = %UpgradeMenu
@onready var _upgrades: Button = %Upgrades
@onready var _battlefield: Battlefield = %Battlefield
@onready var _scroll: ScrollContainer = %Scroll
@onready var _flyers: Control = %Flyers

var _unlock: Button
var _unlock_gap: Control
var _badge: Label
var _badge_style: StyleBoxFlat
var _title := ""
var _app_name: String = ProjectSettings.get_setting("application/config/name")


func _ready() -> void:
	for b: BaseButton in find_children("*", "BaseButton", true, false):
		Hover.button(b)
	get_tree().node_added.connect(_on_node_added)
	if not Hover.enabled():
		var theme := ThemeDB.get_project_theme()
		theme.set_stylebox("hover", "Button", theme.get_stylebox("normal", "Button"))
		theme.set_stylebox("hover", "PriceRow", theme.get_stylebox("normal", "PriceRow"))
	_unlock = Button.new()
	_unlock.name = "UnlockLine"
	_unlock.icon = preload("res://art/ui/credits.png")
	_unlock.custom_minimum_size = UNLOCK_SMALL
	Price.setup(_unlock, Flyers.Kind.CREDITS)
	_unlock.size_flags_horizontal = SIZE_SHRINK_CENTER
	_unlock.mouse_filter = MOUSE_FILTER_PASS
	_unlock.pressed.connect(_on_unlock)
	_unlock_gap = Control.new()
	_unlock_gap.name = "UnlockGap"
	_unlock_gap.custom_minimum_size = Vector2(0, UNLOCK_GAP)
	_unlock_gap.mouse_filter = MOUSE_FILTER_PASS
	_content.add_child(_unlock_gap)
	_content.add_child(_unlock)
	_content.move_child(_unlock_gap, 0)
	_content.move_child(_unlock, 1)
	for i in GameState.lines.size():
		_add_line(i)
	GameState.line_added.connect(_add_line)
	_badge = Label.new()
	_badge.name = "Badge"
	_badge_style = StyleBoxFlat.new()
	_badge_style.bg_color = BADGE_ON
	_badge_style.border_color = Pal.INK
	_badge_style.set_border_width_all(1)
	_badge_style.content_margin_left = 5
	_badge_style.content_margin_right = 5
	_badge.add_theme_stylebox_override("normal", _badge_style)
	_upgrades.add_child(_badge)
	var guide := IntroGuide.new()
	guide.name = "IntroGuide"
	guide.pile = (%Scrapyard as Scrapyard).pile()
	guide.line = line_view(0)
	guide.battlefield = _battlefield
	guide.upgrades = _upgrades
	guide.menu = _menu
	guide.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(guide)
	move_child(guide, $Layout.get_index() + 1)
	guide.z_index = OVERLAY_Z
	_flyers.z_index = FLYERS_Z
	_menu.z_index = TEXT_Z
	for overlay: Control in [%Debug, %Settings, %Nuke]:
		overlay.z_index = OVERLAY_Z + 1
	%Hud.settings_pressed.connect(_settings.open)
	_upgrades.pressed.connect(_toggle_menu)


func _process(_delta: float) -> void:
	_fit_battlefield()
	_upgrades.visible = GameState.revealed() and not GameState.run_over
	_upgrades.text = "CLOSE" if _menu.visible else "UPGRADES"
	var affordable := GameState.affordable_upgrades()
	_badge.visible = not _menu.visible and affordable > 0
	_badge.text = str(affordable)
	var title := "(%d) %s" % [affordable, _app_name] if affordable > 0 and GameState.revealed() and not GameState.run_over else _app_name
	if title != _title:
		_title = title
		DisplayServer.window_set_title(title)
	_badge.reset_size()
	_badge.position = Vector2(_upgrades.size.x - _badge.size.x + 4, -10)
	_unlock.visible = GameState.revealed() and not GameState.upgrade_maxed("lines") and not GameState.run_over
	_unlock_gap.visible = _unlock.visible
	if _unlock.visible:
		var cost := GameState.upgrade_cost("lines")
		var can_buy := GameState.credits >= cost
		Price.show(_unlock, "+ LINE %d  %s" % [GameState.lines.size() + 1, Fmt.num(cost)], can_buy)
		_unlock.custom_minimum_size = UNLOCK_BIG if can_buy else UNLOCK_SMALL


func _fit_battlefield() -> void:
	var pane := _scroll.size.y + _battlefield.size.y
	var h := clampf(pane - _content.get_combined_minimum_size().y, Battlefield.HEIGHT, Battlefield.HEIGHT * FIELD_MAX)
	if _battlefield.custom_minimum_size.y != h:
		_battlefield.custom_minimum_size.y = h


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
