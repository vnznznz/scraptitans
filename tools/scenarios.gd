extends RefCounted

var t: Node


func _init(instrument: Node) -> void:
	t = instrument


func m0() -> void:
	await _fresh()
	var main := t.get_tree().current_scene as Control
	var scroll: ScrollContainer = t.node("Scroll")
	var content: Control = t.node("Content")
	t.check(main.size == Vector2(360, 640), "viewport is 360x640 (got %s)" % main.size)
	t.check(t.node("Hud").size.y == 48 and t.node("Battlefield").size.y == 160, "hud and battlefield heights")
	t.check(scroll.size.y > 300, "scroll pane fills the middle (%d px)" % scroll.size.y)
	t.check(scroll.scroll_vertical + scroll.size.y >= content.size.y - 1, "starts scrolled to the bottom")
	t.check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep_width", "aspect keep_width")

	var pile: Control = t.get_tree().current_scene.find_child("Pile", true, false)
	for i in 5:
		await t.click(pile)
	t.check(is_equal_approx(GameState.scrap, 5.0), "5 clicks on the pile give 5 scrap (got %s)" % GameState.scrap)
	t.check(t.node("Flyers").in_flight() == 5, "each pile tap launches a scrap disc to the HUD")
	await t.wait(0.8)
	t.check(t.node("Flyers").in_flight() == 0, "discs arrive and disappear")

	t.touch(pile, 0, true)
	t.touch(pile, 1, true)
	t.touch(pile, 0, false)
	t.touch(pile, 1, false)
	await t.frames(1)
	t.check(is_equal_approx(GameState.scrap, 7.0), "overlapping two-finger taps both count (got %s)" % GameState.scrap)

	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = pile.get_global_rect().get_center()
	t.get_viewport().push_input(emulated, true)
	var release := emulated.duplicate()
	release.pressed = false
	t.get_viewport().push_input(release, true)
	await t.frames(1)
	t.check(is_equal_approx(GameState.scrap, 7.0), "mouse events emulated from touch don't double count")

	Save.save_game()
	GameState.scrap = 0.0
	t.check(Save.load_game() and is_equal_approx(GameState.scrap, 7.0), "save and load keep scrap")

	t.check(Fmt.num(999) == "999" and Fmt.num(1234) == "1.2K" and Fmt.num(3456789) == "3.4M" and Fmt.num(999999) == "999K",
			"short number suffixes")
	await t.shot("m0")


func m1() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var line: LineView = main.line_view(0)
	var segs := GameState.lines[0].segments
	var pile: Control = main.find_child("Pile", true, false)

	t.check(segs.size() == 3 and not segs.any(func(s: SegmentState) -> bool: return s.built), "line 1 has 3 empty pads")
	await t.click(_build_button(line, 0))
	t.check(not segs[0].built, "can't build without scrap")

	for i in 45:
		await t.click(pile)
	for i in 3:
		await t.click(_build_button(line, i))
	t.check(GameState.lines[0].is_complete() and is_zero_approx(GameState.scrap), "Frame, Core, Arms built for 45 scrap")

	for i in 10:
		await t.click(pile)
	await _fill_bar(line, 0)
	await _fill_bar(line, 1)
	await _fill_bar(line, 2)
	t.check(segs.all(func(s: SegmentState) -> bool: return s.bar_full()), "tapping segments fills their bars")

	GameState.advance(0.3)
	t.check(segs[0].assembling and segs[0].mech != null, "frame spawns a mech and assembles")
	GameState.advance(1.0)
	await t.frames(1)
	t.check(segs[1].mech != null, "mech moved along the belt to core")
	await t.shot("m1_belt")
	GameState.advance(2.0)
	await t.frames(2)
	t.check(GameState.field.size() == 1 and GameState.mechs_built == 1, "mech walked onto the battlefield")
	t.check(GameState.credits >= 5.0 and GameState.credits < 6.0, "deploy fee paid (credits %.2f)" % GameState.credits)
	t.check(is_zero_approx(GameState.scrap), "one mech costs 10 scrap")
	t.check(main.get_node("%Battlefield").mech_count() == 1, "battlefield shows the mech")

	var probe := MechState.new()
	probe.base_rate = 1.0
	var rates := []
	for age in [0.0, 4.9, 5.0, 12.0, 100.0]:
		probe.age = age
		rates.append(snappedf(GameState.payout_rate(probe), 0.001))
	t.check(rates == [1.0, 1.0, 1.5, 2.25, 11.391], "payout steps x1.5 every 5 s, capped at 6 steps %s" % [rates])
	GameState.advance(18.0)
	await t.frames(20)
	await t.shot("m1_field")
	GameState.advance(3.0)
	await t.frames(2)
	var earned := GameState.credits
	t.check(GameState.field.is_empty(), "mech died after its 20 s lifetime")
	t.check(absf(earned - 45.625) < 0.6, "payout rises in steps: 5 fee + 40.6 over life (got %.2f)" % earned)
	t.check(is_equal_approx(GameState.scrap, 2.0), "no scrap while alive, 20%% salvage of 10 on death (got %.2f)" % GameState.scrap)
	t.check(main.get_node("%Battlefield").mech_count() == 0, "battlefield view removed the mech")

	GameState.scrap = 0.0
	await _fill_bar(line, 0)
	GameState.advance(0.1)
	await t.frames(1)
	t.check(segs[0].stall == SegmentState.Stall.NO_SCRAP, "no scrap: frame stalls")
	t.check(line.segment_view(0).get_node("Stall").visible, "stall icon shows")

	GameState.scrap = 100.0
	GameState.advance(1.5)
	t.check(segs[1].mech != null and not segs[1].bar_full(), "mech waits at core with an empty bar")
	await _fill_bar(line, 0)
	GameState.advance(1.0)
	t.check(segs[0].stall == SegmentState.Stall.BLOCKED, "next segment busy: frame is blocked")
	await t.frames(1)
	await t.shot("m1_blocked")

	var before := JSON.stringify(GameState.to_dict(), "", true, true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	var after := JSON.stringify(GameState.to_dict(), "", true, true)
	t.check(before == after, "reload restores the exact state")

	GameState.scrap = 1000.0
	var built_before := GameState.mechs_built
	for i in 10:
		for k in 3:
			await _fill_bar(line, k)
		GameState.advance(3.0)
	t.check(GameState.mechs_built - built_before >= 9, "steady production (%d mechs)" % (GameState.mechs_built - built_before))

	await t.click(main.find_child("SettingsButton", true, false))
	await t.click(main.find_child("Reset", true, false))
	await t.click(main.find_child("Confirm", true, false))
	await t.frames(3)
	t.check(GameState.mechs_built == 0 and not GameState.lines[0].segments[0].built, "settings reset starts a fresh run")


func shots() -> void:
	await _fresh(false)
	await t.shot("fresh")
	var main := t.get_tree().current_scene
	GameState.scrap = 200.0
	for i in 3:
		await t.click(_build_button(main.line_view(0), i))
	GameState.time_scale = 10.0
	for i in 12:
		for s in 3:
			await _fill_bar(main.line_view(0), s)
		await t.frames(10)
	GameState.time_scale = 1.0
	await t.frames(30)
	await t.shot("running")
	var pile: Control = main.find_child("Pile", true, false)
	for i in 4:
		await t.click(pile)
	await t.wait(0.25)
	await t.shot("discs")
	await t.click(main.find_child("DebugToggle", true, false))
	await t.shot("debug")
	await t.click(main.find_child("DebugToggle", true, false))
	await t.click(main.find_child("SettingsButton", true, false))
	await t.shot("settings")


func _fresh(frozen := true) -> void:
	GameState.time_scale = 0.0 if frozen else 1.0
	GameState.new_game()
	t.get_tree().reload_current_scene()
	await t.frames(3)


func _build_button(line: LineView, i: int) -> Button:
	return line.segment_view(i).get_node("Build")


func _fill_bar(line: LineView, i: int) -> void:
	var tap: Control = line.segment_view(i).get_node("Tap")
	for k in 8:
		await t.click(tap)
