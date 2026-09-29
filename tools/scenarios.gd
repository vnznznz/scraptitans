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


func m2() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var field: Battlefield = main.get_node("%Battlefield")
	var hp0 := GameState.wave_max_hp()
	t.check(GameState.wave == 0 and is_equal_approx(GameState.wave_hp, hp0), "wave 1 starts at full HP (%s)" % hp0)
	GameState.advance(5.0)
	t.check(is_equal_approx(GameState.wave_hp, hp0), "no mechs: the bar doesn't drain")
	t.check(field.enemy_count() == 6, "Scrap Drones: 6 enemies")

	_spawn_mechs(3)
	await t.frames(1)
	var label: Label = field.get_child(field.get_child_count() - 1)
	t.check(is_equal_approx(GameState.field_dps(), 3.0) and label.text == "3 DPS", "DPS matches the mech count (%s)" % label.text)
	GameState.advance(2.0)
	t.check(absf(GameState.wave_hp - (hp0 - 6.0)) < 0.2, "3 DPS drains 6 HP in 2 s (%.2f left)" % GameState.wave_hp)
	GameState.advance(hp0 / 2.0 / 3.0 - 2.0)
	await t.frames(1)
	t.check(field.enemy_count() == 3, "half HP: half the drones popped (%d left)" % field.enemy_count())
	await t.shot("m2_half")

	var credits := GameState.credits
	var bounty := GameState.wave_bounty()
	GameState.advance(hp0 / 2.0 / 3.0 + 0.1)
	await t.frames(1)
	t.check(GameState.wave == 1, "drained wave advances to wave 2")
	t.check(GameState.credits - credits > bounty, "bounty of %s paid" % Fmt.num(bounty))
	t.check(GameState.wave_max_hp() > hp0 and Data.wave_type(1).name == "Crawler Tanks", "next wave: Crawler Tanks with more HP")
	t.check(field.enemy_count() == 3, "3 crawlers walk in")
	await t.frames(20)
	await t.shot("m2_cleared")

	GameState.advance(3.0)
	var before := JSON.stringify(GameState.to_dict(), "", true, true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	t.check(before == JSON.stringify(GameState.to_dict(), "", true, true) and GameState.wave == 1, "reload keeps the wave and its HP")

	GameState.kill_wave()
	t.check(GameState.wave == 2 and Data.wave_type(2).name == "Junk Brute", "debug kill wave: Junk Brute next")
	await t.frames(40)
	await t.shot("m2_brute")
	GameState.field.clear()
	var hp := GameState.wave_hp
	GameState.advance(3.0)
	t.check(is_equal_approx(GameState.wave_hp, hp), "field empty: drain stops")


func m3() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var line: LineView = main.line_view(0)
	var segs := GameState.lines[0].segments

	var elapsed := 0.0
	while GameState.credits < GameState.worker_cost(0, 0) and elapsed < 600.0:
		_bot_step()
		GameState.advance(0.2)
		elapsed += 0.2
	t.check(elapsed < 240.0, "tapping bot affords the first worker after %d s" % elapsed)

	GameState.new_game()
	for s in segs.size():
		GameState.lines[0].segments[s].built = true
	segs = GameState.lines[0].segments
	GameState.credits = 10000.0
	var costs := []
	for i in 4:
		costs.append(snappedf(GameState.worker_cost(0, 0), 0.01))
		GameState.hire_worker(0, 0)
	t.check(costs.slice(0, 3) == [50.0, 67.5, 91.13], "worker cost 50·1.35^n %s" % [costs])
	t.check(segs[0].workers == 3, "slot cap 3 stops the 4th hire")

	GameState.advance(0.6)
	var w := segs[0].work
	GameState.advance(0.1)
	t.check(is_equal_approx(segs[0].work - w, 1.0), "3 workers: one chunk every 2/3 s, the bar jumps by 1")

	await _fresh()
	main = t.get_tree().current_scene
	line = main.line_view(0)
	GameState.scrap = 45.0
	for i in 3:
		await t.click(_build_button(line, i))
	GameState.credits = 10000.0
	await t.click(line.segment_view(0).get_node("Hire"))
	await t.click(line.segment_view(1).get_node("Hire"))
	await t.frames(1)
	t.check(GameState.bottlenecks(0) == [2], "no workers on Arms: Arms is the bottleneck")
	t.check(line.segment_view(2).get_node("Bottleneck").visible and not line.segment_view(0).get_node("Bottleneck").visible, "bottleneck highlight on Arms")
	await t.click(line.segment_view(2).get_node("Hire"))
	await t.click(line.segment_view(2).get_node("Hire"))
	await t.frames(1)
	t.check(GameState.bottlenecks(0) == [0] and line.segment_view(0).get_node("Bottleneck").visible, "2 workers on Arms: the highlight moves to Frame (bigger bar)")
	for i in 3:
		while GameState.lines[0].segments[i].workers < 3:
			await t.click(line.segment_view(i).get_node("Hire"))
	for i in 2:
		await t.click(main.find_child("HireYard", true, false))
	t.check(GameState.yard_workers == 2 and GameState.yard_workers == GameState.yard_slots(), "2 yard workers fill the yard slots")
	GameState.credits = 0.0
	GameState.scrap = 20.0
	GameState.advance(60.0)
	var built := GameState.mechs_built
	GameState.advance(60.0)
	t.check(built >= 5 and GameState.mechs_built - built >= 5, "untouched for 2 min: mechs keep coming (%d, then %d)" % [built, GameState.mechs_built - built])
	await t.frames(10)
	await t.shot("m3_workers")

	GameState.kill_wave()
	await t.click(line.get_node("Pause"))
	GameState.advance(25.0)
	var scrap := GameState.scrap
	var field_before := GameState.field.size()
	GameState.advance(10.0)
	t.check(field_before == 0 and GameState.scrap > scrap, "paused: no scrap spent, yard keeps adding (%.0f > %.0f)" % [GameState.scrap, scrap])
	t.check(GameState.lines[0].segments.all(func(s: SegmentState) -> bool: return s.bar_full()), "paused: work banks up")
	await t.frames(1)
	await t.shot("m3_paused")
	await t.click(line.get_node("Pause"))
	GameState.advance(3.0)
	t.check(GameState.scrap < scrap + 20.0 and not GameState.lines[0].paused, "unpaused: production resumes")

	var before := JSON.stringify(GameState.to_dict(), "", true, true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	t.check(before == JSON.stringify(GameState.to_dict(), "", true, true), "reload keeps workers and pause")


func m4() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	await t.click(main.get_node("%Upgrades"))
	t.check(menu.visible, "UPGRADES opens the menu")
	await t.frames(1)
	var buy := _buy(menu, "frame_bar")
	t.check(buy.disabled and menu.find_child("Row_frame_bar", true, false).modulate != Color.WHITE, "unaffordable rows are grey")
	await t.shot("m4_menu")

	GameState.credits = 1e6
	var checks := [
		["segments", "frame_bar", "frame.bar_size", 5.0],
		["workers", "chunk", "worker_chunk", 2.0],
		["yard", "tap", "scrap_per_tap", 2.0],
		["payout", "step_cap", "payout_cap", 7.0],
		["salvage", "salvage", "salvage", 0.25],
		["lines", "lines", "lines", 2.0],
	]
	for c: Array in checks:
		await t.click(menu.find_child("Tab_" + c[0], true, false))
		await t.frames(2)
		await t.click(_buy(menu, c[1]))
		t.check(is_equal_approx(GameState.stat(c[2]), c[3]), "%s tab: %s is now %s" % [c[0], c[2], GameState.stat(c[2])])
	t.check(GameState.lines.size() == 2 and main.line_view(1) != null, "line 2 unlocked and shown")
	t.check(is_equal_approx(GameState.upgrade_cost("tap"), 25.0 * 1.15), "cost base·1.15^level")
	t.check(is_equal_approx(GameState.lines[0].segments[0].bar_size(), 5.0), "sim reads the derived bar size")

	await t.click(main.find_child("Tab_salvage", true, false))
	await t.frames(2)
	for i in 20:
		await t.click(_buy(menu, "salvage"))
	t.check(GameState.upgrade_maxed("salvage") and is_equal_approx(GameState.salvage_share(), 0.9), "salvage stops at 90%")
	await t.shot("m4_salvage")
	await t.click(main.get_node("%Upgrades"))
	t.check(not menu.visible, "the same button closes the menu")

	GameState.scrap = 1000.0
	for l in 2:
		for i in 3:
			await t.click(_build_button(main.line_view(l), i))
	GameState.field.clear()
	for k in 4:
		for l in 2:
			for i in 3:
				await _fill_bar(main.line_view(l), i)
		GameState.advance(3.0)
	t.check(GameState.field.size() >= 7, "both lines feed the battlefield (%d mechs)" % GameState.field.size())
	await t.frames(10)
	await t.shot("m4_lines")

	await t.click(main.find_child("UnlockLine", true, false))
	await t.frames(1)
	t.check(GameState.lines.size() == 3 and main.line_view(2) != null, "pane button unlocks line 3")
	var before := JSON.stringify(GameState.to_dict(), "", true, true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	t.check(before == JSON.stringify(GameState.to_dict(), "", true, true) and GameState.stat("lines") == 3.0, "reload keeps upgrades and lines")


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


func _buy(menu: UpgradeMenu, id: String) -> Button:
	return menu.find_child("Row_" + id, true, false).find_child("Buy", true, false)


func _spawn_mechs(n: int) -> void:
	for i in n:
		var m := MechState.new()
		m.id = GameState.next_mech_id
		GameState.next_mech_id += 1
		m.parts = {"frame": 0, "core": 0, "arms": 0}
		GameState._deploy(m)


func _bot_step() -> void:
	var line := GameState.lines[0]
	for i in line.segments.size():
		var s := line.segments[i]
		if not s.built:
			if GameState.scrap >= GameState.build_cost(0, i):
				GameState.build_segment(0, i)
			else:
				GameState.tap_pile()
			return
	if GameState.scrap < 10.0:
		GameState.tap_pile()
		return
	for i in line.segments.size():
		if GameState.tap_segment(0, i):
			return
	GameState.tap_pile()


func _fill_bar(line: LineView, i: int) -> void:
	var tap: Control = line.segment_view(i).get_node("Tap")
	for k in 8:
		await t.click(tap)
