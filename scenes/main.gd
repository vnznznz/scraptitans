class_name Main
extends Control

const BADGE_ON := Pal.RED
const BADGE_INSET := 8.0
const BAR_H := 56.0
const UNLOCK_SMALL := Vector2(220, 36)
const UNLOCK_BIG := Vector2(300, 44)
const UNLOCK_GAP := 8.0
const FLYERS_Z := 1
const TEXT_Z := 2
const OVERLAY_Z := 3
const ASSEMBLY_WINDOW := 4.0

@onready var _lines: VBoxContainer = %Lines
@onready var _settings: SettingsOverlay = %Settings
@onready var _menu: UpgradeMenu = %UpgradeMenu
@onready var _upgrades: Button = %Upgrades
@onready var _battlefield: Battlefield = %Battlefield
@onready var _scrapyard: Scrapyard = %Scrapyard
@onready var _column: Control = %Column
@onready var _flyers: Flyers = %Flyers
@onready var _rail: ScrollRail = %Rail
@onready var _bar: Control = %Bar
@onready var _spacer: Control = %YardSpacer

var _unlock: Button
var _unlock_slot: Control
var _field_k := 0.0
var _factory_k := 0.0
var _bar_k := 0.0
var _unlock_k := 0.0
var _badge: Label
var _badge_style: StyleBoxFlat
var _title := ""
var _app_name: String = ProjectSettings.get_setting("application/config/name")
var _assemblies := -1
var _assembly_log: Array[Vector2] = []
var _starved := false


func _ready() -> void:
	for b: BaseButton in find_children("*", "BaseButton", true, false):
		Hover.button(b)
		Sound.hook_button(b)
	get_tree().node_added.connect(_on_node_added)
	if not Hover.enabled():
		var theme := ThemeDB.get_project_theme()
		theme.set_stylebox("hover", "Button", theme.get_stylebox("normal", "Button"))
		theme.set_stylebox("hover", "PriceRow", theme.get_stylebox("normal", "PriceRow"))
		theme.set_stylebox("grabber_highlight", "VScrollBar", theme.get_stylebox("grabber", "VScrollBar"))
	_unlock = Button.new()
	_unlock.name = "UnlockLine"
	_unlock.custom_minimum_size = UNLOCK_SMALL
	Price.setup(_unlock, Flyers.Kind.CREDITS, false, true)
	_unlock.mouse_filter = MOUSE_FILTER_PASS
	_unlock.set_meta(&"silent", true)
	_unlock.pressed.connect(_on_unlock)
	_unlock_slot = Control.new()
	_unlock_slot.name = "UnlockSlot"
	_unlock_slot.clip_contents = true
	_unlock_slot.mouse_filter = MOUSE_FILTER_PASS
	_unlock_slot.add_child(_unlock)
	_lines.add_child(_unlock_slot)
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
	guide.pile = _scrapyard.pile()
	guide.rail = %Rail
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
	_upgrades.set_meta(&"silent", true)
	_upgrades.pressed.connect(_toggle_menu)
	_reveal(INF)


func _process(delta: float) -> void:
	_reveal(delta)
	_update_sound()
	_upgrades.text = "CLOSE" if _menu.visible else "UPGRADES"
	var affordable := GameState.affordable_upgrades()
	_badge.visible = not _menu.visible and affordable > 0
	_badge.text = str(affordable)
	var title := "(%d) %s" % [affordable, _app_name] if affordable > 0 and GameState.revealed() and not GameState.run_over else _app_name
	if title != _title:
		_title = title
		DisplayServer.window_set_title(title)
	_badge.reset_size()
	_badge.position = (Vector2(_upgrades.size.x - _badge.size.x - BADGE_INSET, (_upgrades.size.y - _badge.size.y) / 2.0)).round()
	if _unlock_slot.visible:
		var cost := GameState.upgrade_cost("lines")
		var can_buy := GameState.credits >= cost
		Price.show(_unlock, Fmt.num(cost), can_buy, "+ LINE %d" % (GameState.lines.size() + 1))
		_unlock.custom_minimum_size = UNLOCK_BIG if can_buy else UNLOCK_SMALL


func _reveal(delta: float) -> void:
	_field_k = Reveal.step(_field_k, GameState.revealed(), delta, Reveal.SLIDE_TIME)
	var field := Reveal.eased(_field_k)
	_battlefield.visible = _field_k > 0.0
	_battlefield.custom_minimum_size.y = roundf(Battlefield.HEIGHT * field)
	_rail.visible = _field_k > 0.0
	_rail.custom_minimum_size.x = roundf(ScrollRail.WIDTH * field)
	_factory_k = Reveal.step(_factory_k, GameState.shown("factory"), delta, Reveal.SLIDE_TIME)
	var factory := Reveal.eased(_factory_k)
	var first := line_view(0)
	first.visible = _factory_k > 0.0
	first.modulate.a = factory
	_bar_k = Reveal.step(_bar_k, GameState.shown("upgrades") and not GameState.run_over, delta)
	_bar.visible = _bar_k > 0.0
	_bar.custom_minimum_size.y = roundf(BAR_H * Reveal.eased(_bar_k))
	var pane := size.y - (%Hud as Control).custom_minimum_size.y - _bar.custom_minimum_size.y
	_spacer.custom_minimum_size.y = roundf(maxf(0.0, pane - _scrapyard.get_combined_minimum_size().y) / 2.0 * (1.0 - factory))
	_unlock_k = Reveal.step(_unlock_k, GameState.shown("unlock") and not GameState.upgrade_maxed("lines") and not GameState.run_over, delta)
	_unlock_slot.visible = _unlock_k > 0.0
	_unlock_slot.custom_minimum_size.y = roundf((UNLOCK_GAP * 2.0 + _unlock.custom_minimum_size.y) * Reveal.eased(_unlock_k))
	_unlock.size = _unlock.custom_minimum_size
	_unlock.position = Vector2(roundf((_unlock_slot.size.x - _unlock.size.x) / 2.0), UNLOCK_GAP)
	_flyers.clip = _column.get_global_rect()


func _update_sound() -> void:
	Sound.presence.field = Sound.visible_share(_battlefield)
	Sound.presence.factory = Sound.visible_share(_lines)
	Sound.presence.yard = Sound.visible_share(_scrapyard)
	Sound.drives.mechs = _battlefield.mech_count()
	var total := 0
	for line in GameState.lines:
		for seg in line.segments:
			total += seg.assemblies
	var now := Time.get_ticks_msec() / 1000.0
	if _assemblies >= 0 and total > _assemblies:
		_assembly_log.append(Vector2(now, total - _assemblies))
	_assemblies = total
	while not _assembly_log.is_empty() and _assembly_log[0].x < now - ASSEMBLY_WINDOW:
		_assembly_log.pop_front()
	var count := 0.0
	for e in _assembly_log:
		count += e.y
	Sound.drives.assembly_rate = count / ASSEMBLY_WINDOW
	var starved := GameState.starved()
	if starved and not _starved:
		Sound.play(&"stall")
	_starved = starved


func _on_unlock() -> void:
	var cost := GameState.upgrade_cost("lines")
	if GameState.buy_upgrade("lines"):
		Flyers.pay(Flyers.Kind.CREDITS, _unlock, cost)
		Sound.play(&"unlock_line")


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		Hover.button(n)
		Sound.hook_button(n)


func line_view(i: int) -> LineView:
	return _lines.get_node("Line%d" % i)


func _add_line(i: int) -> void:
	var v := LineView.new()
	v.name = "Line%d" % i
	v.line_index = i
	_lines.add_child(v)
	_lines.move_child(v, i)


func _toggle_menu() -> void:
	if _menu.visible:
		_menu.close()
		Sound.play(&"menu_close")
	else:
		_menu.open()
		Sound.play(&"menu_open")
