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
	t.check(t.node("Hud").size.y == 48 and not t.node("Battlefield").visible, "hud 48, no battlefield before the first mech")
	t.check(scroll.size.y >= content.get_combined_minimum_size().y and scroll.size.y == 592.0, "one scroll pane from the HUD to the screen bottom (%d px)" % scroll.size.y)
	t.check(content.get_children().map(func(c: Node) -> String: return c.name) == ["Battlefield", "Lines", "Scrapyard", "YardSpacer"], "pane holds battlefield, lines, scrapyard")
	t.check(scroll.scroll_vertical == 0, "pane starts at the top")
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
	t.check(rates == [1.0, 1.0, 1.0, 1.0, 1.0], "payout starts flat %s" % [rates])
	GameState.advance(18.0)
	await t.frames(20)
	await t.shot("m1_field")
	GameState.advance(3.0)
	await t.frames(2)
	var earned := GameState.credits
	t.check(GameState.field.is_empty(), "mech died after its 20 s lifetime")
	t.check(absf(earned - 25.0) < 0.6, "flat payout: 5 fee + 20 over life (got %.2f)" % earned)
	t.check(is_zero_approx(GameState.scrap), "no scrap while alive, no salvage at first (got %.2f)" % GameState.scrap)
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

	var before := JSON.stringify(GameState.to_dict(), "", true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	var after := JSON.stringify(GameState.to_dict(), "", true)
	t.check(before == after, "reload restores the exact state")

	GameState.scrap = 1000.0
	var built_before := GameState.mechs_built
	for i in 10:
		for k in 3:
			await _fill_bar(line, k)
		GameState.advance(3.0)
	t.check(GameState.mechs_built - built_before >= 9, "steady production (%d mechs)" % (GameState.mechs_built - built_before))

	await t.click(main.find_child("SettingsButton", true, false))
	await t.click(main.get_node("%Settings").find_child("Reset", true, false))
	await t.click(main.get_node("%Settings").find_child("Confirm", true, false))
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
	var xs := field.enemy_xs()
	t.check(xs.all(func(x: float) -> bool: return x > Battlefield.ENEMY_X0 - 8.0 and x < Battlefield.WIDTH), "enemies on screen (%s)" % [xs])

	_spawn_mechs(3)
	await t.frames(1)
	var label: Label = field.get_node("DpsLabel")
	t.check(is_equal_approx(GameState.field_dps(), 3.0) and label.text == "3 DMG/S", "DPS matches the mech count (%s)" % label.text)
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
	t.check(GameState.wave_max_hp() > hp0 and GameState.wave_enemies()[0].sprite == "crawler", "next wave: Crawler Tanks with more HP")
	t.check(field.enemy_count() == 3, "3 crawlers walk in")
	await t.frames(20)
	await t.shot("m2_cleared")

	GameState.advance(3.0)
	var before := JSON.stringify(GameState.to_dict(), "", true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	t.check(before == JSON.stringify(GameState.to_dict(), "", true) and GameState.wave == 1, "reload keeps the wave and its HP")

	GameState.kill_wave()
	t.check(GameState.wave == 2 and GameState.wave_enemies()[0].sprite == "brute", "debug kill wave: Junk Brute next")
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
	while GameState.credits < GameState.worker_cost(0) and elapsed < 600.0:
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
	for i in 10:
		costs.append(snappedf(GameState.worker_cost(0), 0.01))
		GameState.hire_worker(0)
	t.check(costs.slice(0, 3) == [50.0, 55.0, 60.5], "worker cost 50·1.1^n per line %s" % [costs])
	t.check(GameState.lines[0].workers == 9 and GameState.lines[0].worker_slots() == 9, "3 slots per built station: 9, the 10th hire stops")
	t.check([0, 1, 2].all(func(i: int) -> bool: return GameState.lines[0].station_workers(i) == 3), "crew shown 3 per station")

	GameState.lines[0].workers = 3
	GameState.advance(0.6)
	t.check(is_zero_approx(segs[0].work), "no chunk yet")
	GameState.advance(0.1)
	t.check(is_equal_approx(segs[0].work, 1.0) and is_zero_approx(segs[1].work), "3 workers: one chunk every 2/3 s, to the emptiest bar")
	GameState.advance(2.0 / 3.0)
	t.check(is_equal_approx(segs[1].work, 1.0), "the next chunk goes to the next emptiest bar")
	segs[0].work = segs[0].bar_size()
	segs[1].work = segs[1].bar_size()
	segs[2].work = 0.0
	var chunks := segs[2].chunks
	GameState.advance(2.0)
	t.check(segs[2].chunks - chunks == 3 and segs[0].bar_full(), "full bars get no chunks; the crew feeds the empty one")

	await _fresh()
	main = t.get_tree().current_scene
	line = main.line_view(0)
	GameState.scrap = 45.0
	for i in 3:
		await t.click(_build_button(line, i))
	GameState.credits = 10000.0
	_reveal_all()
	while GameState.lines[0].workers < 9:
		await t.click(line.hire_button())
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
	GameState.stalled_once = true
	await t.frames(1)
	await t.click(line.get_node("Pause"))
	GameState.advance(40.0)
	var scrap := GameState.scrap
	var field_before := GameState.field.size()
	GameState.advance(10.0)
	t.check(field_before == 0 and GameState.scrap > scrap, "paused: no scrap spent, yard keeps adding (%.0f > %.0f)" % [GameState.scrap, scrap])
	t.check(GameState.lines[0].segments.all(func(s: SegmentState) -> bool: return s.bar_full()), "paused: work banks up")
	await t.frames(1)
	await t.shot("m3_paused")
	var assembled := GameState.lines[0].segments[0].assemblies
	await t.click(line.get_node("Pause"))
	GameState.advance(3.0)
	t.check(GameState.lines[0].segments[0].assemblies > assembled and not GameState.lines[0].paused, "unpaused: production resumes")

	var before := JSON.stringify(GameState.to_dict(), "", true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	t.check(before == JSON.stringify(GameState.to_dict(), "", true), "reload keeps workers and pause")
	var old_seg := func(w: int) -> Dictionary: return {"type_id": "frame", "built": true, "tier": 0, "work": 0, "mech": null, "assembling": false, "assemble_t": 0, "workers": w}
	t.check(LineState.from_dict({"segments": [old_seg.call(2), old_seg.call(3)]}).workers == 5, "old saves: station workers join the line crew")


func m4() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	_reveal_all()
	await t.frames(1)
	await t.click(main.get_node("%Upgrades"))
	t.check(menu.visible, "UPGRADES opens the menu")
	await t.frames(1)
	var buy := _buy(menu, "tap")
	t.check(buy.disabled and buy.theme_type_variation == &"PriceButton" and menu.row("tap").modulate == Color.WHITE, "unaffordable: normal button, dim price, title readable")
	await t.shot("m4_menu")

	GameState.credits = 1e6
	var checks := [
		["bar", "bar_mult", 0.95],
		["crew", "worker_slots", 4.0],
		["tap", "tap_yard_share", 0.11],
		["raises", "payout_cap", 1.0],
		["salvage", "salvage", 0.04],
		["lines", "lines", 2.0],
	]
	for c: Array in checks:
		await t.click(_buy(menu, c[0]))
		t.check(is_equal_approx(GameState.stat(c[1]), c[2]), "%s is now %s" % [c[1], GameState.stat(c[1])])
	t.check(GameState.lines.size() == 2 and main.line_view(1) != null, "line 2 unlocked and shown")
	GameState.yard_workers = 2
	t.check(is_equal_approx(GameState.tap_scrap(), GameState.stat("scrap_per_tap") + 0.11 * GameState.yard_rate()), "pile tap uses the upgraded crew share (%.2f)" % GameState.tap_scrap())
	GameState.yard_workers = 0
	t.check(is_equal_approx(GameState.upgrade_cost("tap"), 60.0 * Data.econ("upgrade_cost_growth")), "cost base·growth^level")
	t.check(is_equal_approx(GameState.lines[0].segments[0].bar_size(), 5.7), "sim reads the derived bar size")

	GameState.credits = 1e9
	for i in 20:
		await t.click(_buy(menu, "salvage"))
	t.check(GameState.upgrade_maxed("salvage") and is_equal_approx(GameState.salvage_share(), 0.6), "salvage stops at 60%")
	var seg: SegmentState = GameState.lines[0].segments[0]
	var full_cost := float(seg.tier_data().scrap_per_mech)
	GameState.credits = 1e6
	GameState.buy_upgrade("lean")
	t.check(is_equal_approx(seg.scrap_cost(), full_cost * 0.94), "Cheaper parts: 6%% less scrap per part (%s)" % seg.scrap_cost())
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
	var from_lines := GameState.field.map(func(m: MechState) -> int: return m.line)
	t.check(from_lines.has(0) and from_lines.has(1) and from_lines.all(func(l: int) -> bool: return l < 2), "each mech knows the line that built it")
	await t.frames(10)
	await t.shot("m4_lines")

	await t.click(main.find_child("UnlockLine", true, false))
	await t.frames(1)
	t.check(GameState.lines.size() == 3 and main.line_view(2) != null, "pane button unlocks line 3")
	var before := JSON.stringify(GameState.to_dict(), "", true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	t.check(before == JSON.stringify(GameState.to_dict(), "", true) and GameState.stat("lines") == 3.0, "reload keeps upgrades and lines")


func m5() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	var line: LineView = main.line_view(0)
	var segs := GameState.lines[0].segments
	t.check(not line.get_node("Pause").visible and _centered(line, 3), "fresh game: no pause strip, 3 segments centered (x %d)" % line.segment_view(0).position.x)
	GameState.stalled_once = true
	await t.frames(1)
	t.check(line.get_node("Pause").visible and line.get_node("Pause").position.x < 20, "after a stall: pause sits at the left of the line")
	t.check(_centered(line, 3), "3 segments centered right of the pause strip (x %d)" % line.segment_view(0).position.x)
	var pause_rect: Rect2 = line.get_node("Pause").get_rect()
	t.check(is_zero_approx(pause_rect.position.y) and pause_rect.end.y >= SegmentView.BELT_Y and pause_rect.end.x <= line.segment_view(0).position.x, "pause strip spans names to belt, left of the stations")

	_reveal_all()
	await t.frames(1)
	await t.click(main.get_node("%Upgrades"))
	await t.frames(1)
	t.check(_sorted(menu), "one list, cheapest first, maxed last")
	t.check(menu.row("final_arms").visible and _buy(menu, "final_arms").disabled, "Atomic Missile row visible and locked")
	await t.shot("m5_menu")
	await t.click(main.get_node("%Upgrades"))

	GameState.scrap = 45.0
	for i in 3:
		await t.click(_build_button(line, i))
	GameState.credits = 1000.0
	await t.frames(1)
	var hire := line.hire_button()
	var crew: Label = line.get_node("Crew")
	t.check(hire.visible and not hire.disabled and crew.text == "LINE CREW 0/9", "one hire button per line, crew 0/9")
	var pause: Control = line.get_node("Pause")
	t.check(hire.position.y == 1.0 and hire.get_rect().end.y == LineView.CREW_H and is_equal_approx(hire.get_rect().end.x, line.size.x + 1.0), "hire sits in the crew bar at the right, on its bottom edge, its right border under the rail seam")
	t.check(is_equal_approx(pause.position.y, LineView.CREW_H) and crew.position.x >= pause.size.x and line.segment_view(0).position.y >= LineView.CREW_H, "crew bar on top, pause strip below it at the left: an L")
	for i in 9:
		await t.click(hire)
	await t.frames(1)
	t.check(not hire.visible and crew.text == "LINE CREW 9/9", "full crew: hire hidden, no MAX")
	t.check(not line.segment_view(0).get_node("Apply").visible and line.segment_view(0).get_node("Header").visible, "nothing to fit: station name shown")

	GameState.scrap = 0.0
	await _fill_bar(line, 0)
	GameState.advance(0.2)
	await t.frames(1)
	var rate: Label = main.get_node("%Hud")._scrap_rate
	t.check(GameState.starved() and rate.modulate == Hud.STARVED, "no scrap: HUD scrap rate turns red")
	GameState.scrap = 100.0
	GameState.advance(0.2)
	await t.frames(1)
	t.check(not GameState.starved() and rate.modulate == Hud.RATE_COLOR, "scrap back: normal color")

	var apply0: Button = line.segment_view(0).get_node("Apply")
	t.check(not apply0.visible, "no tier to apply yet: no fit button")
	await t.click(main.get_node("%Upgrades"))
	GameState.credits = 80.0
	await t.click(_buy(menu, "tier_frame"))
	t.check(GameState.unlocked_tier("frame") == 1, "Bolted Frame unlocked for 80 credits")
	await t.shot("m5_unlocked")
	await t.click(main.get_node("%Upgrades"))

	await t.click(line.get_node("Pause"))
	GameState.scrap = 0.0
	GameState.advance(10.0)
	t.check(GameState.lines[0].paused and is_zero_approx(GameState.scrap), "paused line saves scrap")
	GameState.scrap = 30.0
	await t.frames(1)
	await t.click(line.segment_view(0).get_node("Apply"))
	t.check(segs[0].tier == 1 and is_zero_approx(GameState.scrap), "apply Bolted Frame for 30 scrap")
	await t.click(line.get_node("Pause"))
	GameState.scrap = 1000.0
	GameState.field.clear()
	for k in 3:
		for i in 3:
			await _fill_bar(line, i)
		GameState.advance(3.0)
	var m: MechState = GameState.field[-1]
	t.check(m.parts.frame == 1 and is_equal_approx(m.lifetime, 26.0), "new mechs have Bolted Frames and live 26 s")
	t.check(is_equal_approx(m.scrap_cost, 14.0 + 3.0 + 3.0), "scrap per mech rises to 20")
	await t.frames(30)
	await t.shot("m5_bolted")

	GameState.credits = 1000.0
	GameState.buy_upgrade("tier_plating")
	await t.frames(2)
	t.check(segs.size() == 4 and line.segment_view(3) != null, "plating unlock adds a 4th pad")
	t.check(_centered(line, 4), "4 segments re-centered (x %d)" % line.segment_view(0).position.x)
	t.check(pause_rect.end.x <= line.segment_view(0).position.x and line.segment_view(3).position.x + SegmentView.WIDTH <= 360.0, "4 columns fit beside the pause strip")
	t.check(SegmentView.WIDTH + 2.0 < LineView.SEG_STEP, "shared button rows (82 px) leave a gap at step %d" % LineView.SEG_STEP)
	await t.click(_build_button(line, 3))
	t.check(segs[3].built, "plating built on line 1")
	GameState.field.clear()
	for k in 4:
		for i in 4:
			await _fill_bar(line, i)
		GameState.advance(3.0)
	m = GameState.field[-1]
	t.check(m.parts.has("plating") and is_equal_approx(m.lifetime, 36.0), "plated mechs live 36 s (%s)" % m.lifetime)
	for i in 4:
		await _fill_bar(line, i)
	var deployed := GameState.field.size()
	for k in 60:
		GameState.advance(0.1)
		await t.frames(1)
		if GameState.field.size() > deployed:
			break
	var leaving := line._mechs.get_children().filter(func(v: Node) -> bool: return v is MechView and v._shown.has("plating"))
	t.check(GameState.field.size() > deployed and not leaving.is_empty(), "mech leaves the belt with its plating shown")
	await t.frames(30)
	await t.shot("m5_plating")

	for l in GameState.lines:
		l.paused = true
	GameState.wave = 10
	var aged := MechState.new()
	aged.lifetime = 20.0
	GameState.field = [aged]
	var aging := 1.0 + float(Data.enemies.wave_damage) * 10.0
	GameState.advance(20.0 / aging - 0.2)
	t.check(GameState.field.size() == 1, "wave 11: mechs age %.1fx, alive at %.1f s" % [aging, 20.0 / aging - 0.2])
	GameState.advance(0.3)
	t.check(GameState.field.is_empty(), "and dead after %.1f s" % (20.0 / aging + 0.1))


func m6() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var field: Battlefield = main.get_node("%Battlefield")
	GameState.time_scale = 1.0
	GameState.debug_spawn_mechs(3)
	await t.frames(2)
	var view := field.mech_view(GameState.field[0].id)
	t.check(view.walking, "mechs walk in")
	await t.wait(7.5)
	t.check(not view.walking, "and hold a slot")
	var bullets := field.find_children("*", "Sprite2D", true, false).filter(func(n: Node) -> bool:
		return n.texture and n.texture.resource_path.contains("shot_"))
	await t.shot("m6_fight")
	var fired := 0
	for k in 60:
		await t.frames(1)
		fired = maxi(fired, field.find_children("*", "Sprite2D", true, false).filter(func(n: Node) -> bool:
			return n.texture and n.texture.resource_path.begins_with("res://art/fx/shot_")).size())
	t.check(fired > 0 or bullets.size() > 0, "mechs fire at the wave")
	var drone: Sprite2D = field.find_children("*", "Sprite2D", true, false).filter(func(n: Sprite2D) -> bool:
		return n.texture and n.texture.resource_path.contains("enemy_")).front()
	var drawn := drone.get_rect()
	drawn.position += drone.position
	t.check(drawn.has_point(field.call("_enemy_center", drone)) and absf(field.call("_enemy_center", drone).y - drawn.get_center().y) < 1.0, "bullets aim at the enemy's drawn center")

	var m: MechState = GameState.field[0]
	for pair: Array in [[0.9, 0], [0.35, 1], [0.2, 2], [0.12, 3], [0.05, 4]]:
		m.wear = m.lifetime * (1.0 - pair[0])
		await t.frames(1)
		t.check(view.damage_stage() == pair[1], "remaining %d%%: damage stage %d" % [pair[0] * 100, pair[1]])
	await t.shot("m6_damaged")

	GameState.debug_spawn_mechs(50)
	await t.frames(2)
	t.check(field.mech_count() == 24 and GameState.field.size() == 53, "53 mechs simulated, 24 drawn")
	var elite := MechState.new()
	elite.id = GameState.next_mech_id
	GameState.next_mech_id += 1
	for type_id: String in ["frame", "core", "arms"]:
		elite.parts[type_id] = 3
	GameState._deploy(elite)
	await t.frames(2)
	var elite_view := field.mech_view(elite.id)
	t.check(elite_view != null and field.mech_count() == 24, "a better mech replaces the weakest drawn one")
	t.check(elite_view != null and int(elite_view.get_meta("row")) == 0, "and takes the front row")
	await t.wait(4.0)
	t.check(elite_view != null and not elite_view.walking and is_equal_approx(elite_view.position.y, Battlefield.ROW_Y[0]), "it reaches its front slot within 4 s")
	await t.wait(2.0)
	var max_discs := 0
	var start := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - start < 4000:
		await t.frames(1)
		frames += 1
		max_discs = maxi(max_discs, main.get_node("%Flyers").in_flight())
	print("  fps with 53 mechs: %.0f" % (frames / 4.0))
	t.check(max_discs <= 30 and max_discs > 0, "income discs stay readable (max %d in flight)" % max_discs)
	await t.shot("m6_50")


func m7() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	var nuke: Nuke = main.get_node("%Nuke")
	var line: LineView = main.line_view(0)
	GameState.credits = 1e8
	GameState.scrap = 1e7
	for i in 3:
		await t.click(_build_button(line, i))
	for i in 3:
		GameState.hire_worker(0)
	_reveal_all()
	await t.frames(1)
	await t.click(main.get_node("%Upgrades"))
	for i in 4:
		await t.click(_buy(menu, "tier_arms"))
	t.check(GameState.unlocked_tier("arms") == 4, "Railgun unlocked")
	await t.frames(1)
	var final_effect: Label = menu.row("final_arms").find_child("Effect", true, false)
	t.check(GameState.upgrade_locked("final_arms") and _buy(menu, "final_arms").disabled and final_effect.text == "NEEDS ALL PARTS", "Arms maxed alone: Atomic Missile still locked (%s)" % final_effect.text)
	for id: String in ["tier_frame", "tier_core", "tier_plating"]:
		while not GameState.upgrade_maxed(id):
			GameState.buy_upgrade(id)
			if id != "tier_plating":
				t.check(GameState.upgrade_locked("final_arms"), "missile locked while %s isn't maxed" % id)
	await t.frames(2)
	t.check(not GameState.upgrade_locked("final_arms") and not _buy(menu, "final_arms").disabled, "every part unlocked: missile can be bought")
	var final_desc: Label = menu.row("final_arms").find_child("Desc", true, false)
	t.check(final_effect.text == "ENDS THE WAR" and final_desc.text.begins_with("ENDS THE WAR"), "missile row and help say it ends the war")
	await t.shot("m7_final")
	await t.click(_buy(menu, "final_arms"))
	t.check(GameState.unlocked_tier("arms") == 5 and menu.find_child("Confirm", true, false) == null, "Atomic Missile unlocked at once, no confirm")
	await t.click(main.get_node("%Upgrades"))
	var segs := GameState.lines[0].segments
	t.check(segs.size() == 4, "plating pad added")
	await t.click(line.segment_view(2).get_node("Apply"))
	t.check(segs[2].tier == 4 and not GameState.can_apply_tier(0, 2), "line not maxed: Arms fit stops at the Railgun")
	await t.click(_build_button(line, 3))
	for i in [0, 1]:
		await t.click(line.segment_view(i).get_node("Apply"))
	await t.frames(1)
	t.check(not GameState.can_apply_tier(0, 2) and not line.segment_view(2).get_node("Apply").visible, "one station short of its best part: still no missile")
	await t.click(line.segment_view(3).get_node("Apply"))
	await t.frames(1)
	t.check(GameState.line_maxed(0) and GameState.can_apply_tier(0, 2), "every station at its best part: missile can be fitted")
	await t.click(line.segment_view(2).get_node("Apply"))
	t.check(segs[2].tier == 5, "applied to the Arms segment")

	GameState.time_scale = 1.0
	var start := Time.get_ticks_msec()
	while not GameState.run_over and Time.get_ticks_msec() - start < 20000:
		for i in segs.size():
			GameState.tap_segment(0, i)
		await t.frames(1)
	t.check(GameState.run_over and nuke.visible, "Nuclear Mech deploys, input locked")
	await t.wait(3.0)
	await t.shot("m7_walk")
	await t.wait(3.6)
	await t.shot("m7_launch")
	await t.wait(1.4)
	await t.shot("m7_cloud")
	await t.wait(2.4)
	await t.shot("m7_sweep")
	start = Time.get_ticks_msec()
	while not nuke.card_visible() and Time.get_ticks_msec() - start < 20000:
		await t.frames(1)
	t.check(nuke.card_visible(), "run stats card after %.1f s" % ((Time.get_ticks_msec() - start) / 1000.0))
	t.check(not line.get_node("Segment0").visible, "factory collapsed")
	await t.shot("m7_card")

	Save.save_game()
	t.get_tree().reload_current_scene()
	await t.frames(3)
	Save.load_game()
	t.get_tree().reload_current_scene()
	await t.frames(3)
	main = t.get_tree().current_scene
	t.check(GameState.run_over and main.get_node("%Nuke").card_visible(), "reload shows the card, not the old run")
	await t.click(main.get_node("%Nuke").find_child("StartAgain", true, false))
	await t.frames(3)
	main = t.get_tree().current_scene
	t.check(not GameState.run_over and GameState.mechs_built == 0 and not main.get_node("%Nuke").visible, "Start again gives a fresh game")


func m8() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var line: LineView = main.line_view(0)
	var segs := GameState.lines[0].segments
	var yard_hire: Control = main.find_child("HireYard", true, false)
	var hidden := [main.get_node("%Upgrades"), main.find_child("UnlockLine", true, false), yard_hire]
	t.check(hidden.all(func(c: Control) -> bool: return not c.is_visible_in_tree()), "fresh game: UPGRADES, UNLOCK LINE, YARD WORKER hidden")
	GameState.scrap = 45.0
	for i in 3:
		await t.click(_build_button(line, i))
	await t.frames(1)
	t.check(not line.get_node("Crew").visible and not line.hire_button().visible and is_zero_approx(line.segment_view(0).position.y), "stations built, no mech yet: no crew bar, stations at the top")
	GameState.scrap = 100.0
	for k in 3:
		await _fill_bar(line, k)
	GameState.advance(3.0)
	await t.frames(1)
	hidden.append(line.get_node("Crew"))
	t.check(GameState.mechs_built == 1 and main.get_node("%Battlefield").visible and hidden.all(func(c: Control) -> bool: return not c.is_visible_in_tree()),
			"first mech deployed: battlefield in, buying UI still hidden")
	GameState.credits = 1000.0
	await t.frames(2)
	t.check(hidden.all(func(c: Control) -> bool: return c.is_visible_in_tree()), "credits for them: the buttons and crew row appear")

	t.check(line.size.y < 200.0, "line takes %d px (M7: 238)" % line.size.y)
	t.check(line.segment_view(0).find_child("Jump", false, false) == null and line.segment_view(0).find_child("Bottleneck", false, false) == null, "no jump button, no bottleneck box")
	var hud: Hud = main.get_node("%Hud")
	t.check(hud.target(Flyers.Kind.SCRAP).x < hud.target(Flyers.Kind.CREDITS).x, "HUD: scrap left, credits right")

	GameState.field.clear()
	GameState.credits = 1e6
	for i in 9:
		GameState.hire_worker(0)
	GameState.scrap = 1e4
	GameState.advance(8.0)
	await t.frames(1)
	var rate: Label = hud._scrap_rate
	t.check(GameState.scrap_rate < 0.0 and rate.text.begins_with("-"), "lines consume scrap: net rate %s" % rate.text)
	t.check(GameState.scrap_gain_rate == 0.0, "no scrap income")

	GameState.new_game()
	for i in 3:
		GameState.lines[0].segments[i].built = true
	GameState.debug_spawn_mechs(1)
	var m: MechState = GameState.field[0]
	m.scrap_cost = 10.0
	m.age = 30.0
	t.check(is_equal_approx(GameState.payout_rate(m), 1.0), "flat payout at first")
	GameState.credits = 1e6
	GameState.buy_upgrade("raises")
	GameState.buy_upgrade("raises")
	t.check(is_equal_approx(GameState.payout_rate(m), 2.25), "2 pay raises: x1.5 twice (%s)" % GameState.payout_rate(m))
	GameState.buy_upgrade("raise_time")
	m.age = 4.75
	t.check(is_equal_approx(GameState.payout_rate(m), 1.5), "faster raises: first raise at 4.7 s")
	for i in 20:
		GameState.buy_upgrade("salvage")
	t.check(is_equal_approx(GameState.salvage_share(), 0.4), "salvage capped at 40%")

	segs = GameState.lines[0].segments
	var bar0 := segs[0].bar_size()
	GameState.buy_upgrade("tier_frame")
	GameState.scrap = 1000.0
	GameState.apply_tier(0, 0)
	t.check(segs[0].bar_size() > bar0, "applying a tier grows the bar (%d > %d)" % [segs[0].bar_size(), bar0])

	await _fresh()
	main = t.get_tree().current_scene
	line = main.line_view(0)
	_reveal_all()
	GameState.scrap = 45.0
	for i in 3:
		await t.click(_build_button(line, i))
	GameState.credits = 400.0
	await t.click(main.get_node("%Upgrades"))
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	var no_desc := Data.upgrade_list.filter(func(r: Dictionary) -> bool:
		var desc: Label = menu.row(r.id).find_child("Desc", true, false)
		return desc.text.length() < 10 or menu.row(r.id).find_child("Info", true, false) == null)
	t.check(no_desc.is_empty(), "every row has an info button and a description %s" % [no_desc.map(func(r: Dictionary) -> String: return r.id)])
	var tap_row := menu.row("tap")
	await t.click(tap_row.find_child("Info", true, false))
	t.check(tap_row.find_child("Desc", true, false).visible, "info button shows the description")
	await t.shot("m8_info")
	await t.click(_buy(menu, "tier_frame"))
	await t.click(main.get_node("%Upgrades"))
	GameState.scrap = 100.0
	await t.frames(1)
	var sv := line.segment_view(0)
	var apply: Button = sv.get_node("Apply")
	t.check(apply.visible and not sv.get_node("Header").visible and apply.get_rect().end.y == SegmentView.MACHINE_Y + 1.0, "fit replaces the station name, bottom row on the machine's top edge %s" % apply.get_rect())
	t.check(apply.position.x >= -2.0 and apply.get_rect().end.x <= 82.0, "it fits the station (%s)" % apply.get_rect())
	await t.shot("m8_row")
	await t.click(apply)
	t.check(GameState.lines[0].segments[0].tier == 1, "apply from the header")

	var kinds := {}
	var variants := {}
	for w in 30:
		var list := Data.wave_enemies(w)
		var sprites := {}
		for e in list:
			sprites[e.sprite] = true
			variants[e.variant] = true
		kinds[w] = sprites.size()
	t.check(kinds[0] == 1 and kinds[5] == 1 and kinds[8] >= 2 and kinds[20] == 3, "later waves mix types %s" % [kinds.values()])
	t.check(variants.size() >= 4, "tinted variants appear as waves climb %s" % [variants.keys()])
	t.check(Data.wave_enemies(20).size() > Data.wave_enemies(0).size(), "more enemies per wave (%d > %d)" % [Data.wave_enemies(20).size(), Data.wave_enemies(0).size()])
	var list := Data.wave_enemies(11)
	t.check(list[0].weight <= list[-1].weight, "weakest enemies pop first")

	var field: Battlefield = main.get_node("%Battlefield")
	GameState.field.clear()
	GameState.wave = 16
	GameState.wave_hp = GameState.wave_max_hp()
	await t.frames(40)
	GameState.debug_spawn_mechs(10)
	GameState.wave_hp = GameState.wave_max_hp() * 0.2
	await t.frames(60)
	var enemies := field.find_children("Damage", "DamageFx", true, false).filter(func(d: DamageFx) -> bool:
		return (d.get_parent() as CanvasItem).visible)
	t.check(enemies.size() > 0 and enemies.all(func(d: DamageFx) -> bool: return d.stage >= 2), "wave at 20%%: %d enemies smoke" % enemies.size())
	var tinted := field.find_children("*", "Sprite2D", true, false).filter(func(n: Sprite2D) -> bool:
		return n.texture and n.texture.resource_path.contains("enemy_") and not n.texture.resource_path.ends_with("_1.png"))
	t.check(tinted.size() > 0, "wave 17 shows tinted enemies (%d)" % tinted.size())
	await t.shot("m8_wave")

	t.check(Flyers.tier(Flyers.Kind.CREDITS, 0.5) == 0 and Flyers.tier(Flyers.Kind.CREDITS, 1e9) == 2, "disc tier by payout size")
	var flyers: Flyers = main.get_node("%Flyers")
	for c in flyers.get_children():
		c.free()
	GameState.kill_wave()
	await t.frames(1)
	t.check(flyers.get_children().any(func(d: TextureRect) -> bool: return d.texture == Flyers.TEXTURES[0][2]), "wave bounty flies as top-tier discs")

	GameState.credits = 1e9
	for i in 5:
		GameState.buy_upgrade("kill_scrap")
	GameState.wave_hp = GameState.wave_max_hp()
	for c in flyers.get_children():
		c.free()
	var scrap := GameState.scrap
	var first := GameState.wave_enemies()[0]
	var expect := GameState.kill_scrap(first)
	GameState.wave_hp = GameState.wave_max_hp() * (1.0 - first.weight / GameState.wave_enemies().reduce(func(a: float, e: Dictionary) -> float: return a + e.weight, 0.0)) + 0.01
	GameState.advance(0.1)
	await t.frames(1)
	t.check(is_equal_approx(expect, 50.0 * pow(float(Data.enemies.variant_scrap), first.variant)), "kill scrap: 50 per enemy × %s^variant %d, not a share of its HP" % [Data.enemies.variant_scrap, first.variant])
	t.check(absf(GameState.scrap - scrap - expect) < 1.0, "the popped enemy pays %s scrap (got %s)" % [Fmt.num(expect), Fmt.num(GameState.scrap - scrap)])
	t.check(flyers.get_children().any(func(d: TextureRect) -> bool: return Flyers.TEXTURES[1].has(d.texture)), "and sends scrap discs")
	await t.shot("m8_kill")

	await _fresh()
	main = t.get_tree().current_scene
	line = main.line_view(0)
	flyers = main.get_node("%Flyers")
	GameState.scrap = 100.0
	for i in 3:
		await t.click(_build_button(line, i))
	await t.wait(0.3)
	for c in flyers.get_children():
		c.free()
	await _fill_bar(line, 0)
	GameState.advance(0.1)
	await t.frames(2)
	var hud_scrap: Vector2 = main.get_node("%Hud").target(Flyers.Kind.SCRAP)
	t.check(GameState.lines[0].segments[0].assembling and flyers.get_child_count() == 1, "assembly sends a scrap disc from the HUD")
	t.check(flyers.get_child(0).position.distance_to(hud_scrap) < 40.0, "it starts at the scrap counter")
	t.check(line.find_children("*", "CPUParticles2D", true, false).size() >= 2, "scrap bits and sparks drop onto the mech")
	await t.wait(0.2)
	await t.shot("m8_consume")

	GameState.advance(1.0)
	await _fill_bar(line, 0)
	GameState.advance(1.0)
	await t.frames(1)
	var usage: ColorRect = line.find_child("Usage", true, false)
	GameState.advance(1.0)
	await t.frames(2)
	t.check(GameState.lines[0].scrap_used_rate > 0.0 and usage.size.y > 0.0, "line scrap use shows as a meter (%d px)" % usage.size.y)
	var stall: Control = line.segment_view(0).get_node("Stall")
	t.check(GameState.lines[0].segments[0].stall == SegmentState.Stall.BLOCKED and not stall.visible, "blocked: no icon yet")
	GameState.time_scale = 10.0
	await t.wait(0.1)
	t.check(not stall.visible, "still hidden after 1 s")
	await t.wait(0.25)
	t.check(stall.visible, "blocked icon after 3 s")
	GameState.time_scale = 0.0

	await _fresh()
	main = t.get_tree().current_scene
	var scrapyard: Control = main.get_node("%Scrapyard")
	var yard: Control = scrapyard.get_node("Yard")
	var pile_x := func() -> float: return yard.get_node("PileSprite").get_global_rect().get_center().x
	var yard_x := func() -> float: return scrapyard.get_global_rect().get_center().x
	t.check(absf(pile_x.call() - yard_x.call()) < 2.0, "pile centered in the yard (%d vs %d)" % [pile_x.call(), yard_x.call()])
	await t.shot("m8_yard_centered")
	GameState.credits = 100.0
	_reveal_all()
	await t.frames(2)
	var hire: Button = scrapyard.get_node("HireYard")
	t.check(absf(pile_x.call() - yard_x.call()) < 2.0 and scrapyard.get_node("Crew").visible and hire.visible
			and hire.get_global_rect().end.x == scrapyard.get_global_rect().end.x + 1.0 and yard.position.y == LineView.CREW_H,
			"after the reveal: pile stays centered under a yard crew bar, hire flush right (border under the rail seam)")
	var badge: Label = main.get_node("%Upgrades").get_node("Badge")
	t.check(badge.visible and badge.text == str(GameState.affordable_upgrades()) and GameState.affordable_upgrades() > 0, "UPGRADES shows %s affordable" % badge.text)
	t.check(main.get("_title") == "(%d) Scrap Titans" % GameState.affordable_upgrades(), "window title shows the count: %s" % main.get("_title"))
	await t.shot("m8_badge")
	GameState.credits = 0.0
	await t.frames(2)
	t.check(not badge.visible, "no badge when nothing is affordable")
	t.check(main.get("_title") == "Scrap Titans", "plain title when nothing is affordable")

	var hud_mechs: Label = main.find_child("Mechs", true, false)
	var hud_rate: Label = main.find_child("MechsRate", true, false)
	var on_field := GameState.field.size()
	GameState.debug_spawn_mechs(3)
	GameState.advance(1.1)
	await t.frames(2)
	t.check(hud_mechs.text == str(on_field + 3) and GameState.mechs_per_min == 3 and hud_rate.text == "3/MIN", "HUD: %s mechs, %s" % [hud_mechs.text, hud_rate.text])
	GameState.advance(60.0)
	await t.frames(2)
	t.check(GameState.mechs_per_min == 0 and hud_rate.text == "0/MIN", "rate covers the last minute")
	GameState.field.pop_back()
	await t.frames(2)
	t.check(hud_mechs.text == str(GameState.field.size()), "HUD counts mechs on the field, not built")

	GameState.wave = 3
	GameState.wave_hp = GameState.wave_max_hp()
	GameState.credits = 0.0
	await t.frames(30)
	var field_tap: Control = main.find_child("FieldTap", true, false)
	flyers = main.get_node("%Flyers")
	for c in flyers.get_children():
		c.free()
	GameState.field.clear()
	await t.click(field_tap)
	var floor_dps := float(Data.tier("arms", 0).dps)
	t.check(is_equal_approx(GameState.wave_max_hp() - GameState.wave_hp, 0.2 * floor_dps), "empty field: a tap deals 0.2 s of tier 1 Arms DPS")
	t.check(is_zero_approx(GameState.credits) and flyers.get_child_count() == 0, "taps pay no credits, send no discs")
	GameState.debug_spawn_mechs(10)
	GameState.wave = 8
	GameState.wave_hp = GameState.wave_max_hp()
	var field_dps := GameState.field_dps()
	await t.click(field_tap)
	t.check(is_equal_approx(GameState.wave_max_hp() - GameState.wave_hp, 0.2 * field_dps), "10 mechs: a tap deals 0.2 s of field DPS (%s)" % Fmt.num(field_dps * 0.2))
	GameState.advance(1.0)
	var dps_label: Label = main.find_child("DpsLabel", true, false)
	await t.frames(1)
	t.check(GameState.tap_dps > 0.0 and is_equal_approx(GameState.wave_dps(), field_dps + GameState.tap_dps), "wave DPS includes tap damage (%s)" % dps_label.text)
	GameState.credits = 1e6
	for i in 4:
		GameState.buy_upgrade("tap_damage")
	var hp := GameState.wave_hp
	await t.click(field_tap)
	t.check(is_equal_approx(hp - GameState.wave_hp, GameState.field_dps() * 0.52), "Harder hits chain: 4 levels, 0.52 s per tap")
	GameState.wave_hp = GameState.field_dps() * 0.3
	var wave := GameState.wave
	await t.click(field_tap)
	t.check(GameState.wave == wave + 1, "taps can finish a wave")

	var pile: Control = main.find_child("Pile", true, false)
	var pile_sprite: Control = yard.get_node("PileSprite")
	var rest_x := pile_sprite.position.x
	await t.click(pile)
	t.check(not is_equal_approx(pile_sprite.position.x, rest_x), "pile vibrates on tap")
	await t.wait(0.3)
	t.check(is_equal_approx(pile_sprite.position.x, rest_x), "and settles back")
	_reveal_all()
	GameState.yard_workers = 20
	GameState.levels["yard_crew"] = 20
	GameState.levels["interval"] = 10
	GameState._stats.clear()
	var scale := GameState.time_scale
	GameState.time_scale = 1.0
	GameState.scrap = GameState.yard_rate() * 40.0
	var tallest := 0.0
	var lowest := 2
	for f in 120:
		if f % 30 == 0:
			pile.tapped.emit(Vector2(10, 10))
		await t.frames(1)
		tallest = maxf(tallest, pile_sprite.scale.y)
		lowest = mini(lowest, (yard.get_parent() as Scrapyard).pile_level())
	t.check(tallest > 0.99 and lowest == 2, "busy yard + taps: the pile still springs back (%.3f) and keeps its size (%d)" % [tallest, lowest])
	GameState.time_scale = scale
	GameState.yard_workers = 0
	GameState.levels.erase("yard_crew")
	GameState.levels.erase("interval")
	GameState._stats.clear()

	var motion := InputEventMouseMotion.new()
	motion.position = pile.get_global_rect().get_center()
	motion.global_position = motion.position
	t.get_viewport().push_input(motion, true)
	await t.frames(2)
	t.check(pile.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "pile shows a hand cursor")
	t.check(not Hover.enabled() or yard.get_node("PileSprite").self_modulate == Hover.TINT, "hovering the pile lights it up")
	var gear: Button = main.find_child("SettingsButton", true, false)
	t.check(gear.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and main.get_node("%Upgrades").mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "buttons show a hand cursor")


	await _fresh()
	main = t.get_tree().current_scene
	line = main.line_view(0)
	flyers = main.get_node("%Flyers")
	GameState.scrap = 100.0
	await t.click(_build_button(line, 0))
	t.check(flyers.get_child_count() == 2 and flyers.get_children().all(func(d: TextureRect) -> bool: return d.texture == Flyers.TEXTURES[1][2]),
			"building for 10 scrap sends 2 scrap discs (no scrap income yet: top tier)")
	for i in 2:
		await t.click(_build_button(line, i + 1))
	await t.wait(0.8)
	t.check(flyers.get_child_count() == 0, "spend discs land and disappear")
	_reveal_all()
	GameState.credits = 5000.0
	await t.frames(2)
	var hire_button: Button = line.hire_button()
	await t.click(hire_button)
	var discs := flyers.get_children()
	t.check(discs.size() == 2 and discs.all(func(d: TextureRect) -> bool: return Flyers.TEXTURES[0].has(d.texture)), "hiring for 50 credits sends 2 credit discs (%d)" % discs.size())
	await t.wait(0.3)
	await t.shot("m8_hire_discs")
	await t.wait(0.3)
	await t.click(main.get_node("%Upgrades"))
	var menu_buy := _buy(main.get_node("%UpgradeMenu"), "crew")
	for c in flyers.get_children():
		c.free()
	await t.click(menu_buy)
	t.check(flyers.get_child_count() == 3, "a 300 credit upgrade sends 3 discs (%d)" % flyers.get_child_count())
	await t.shot("m8_pay")


const PROFILES := {
	"baseline": {},
	"casual": {"taps": 1.5},
	"field": {"field": 1.0},
	"third": {"field": 1.0 / 3.0},
	"quit10": {"stop": 600.0},
	"no_arms": {"no_arms": true},
	"no_pause": {"no_pause": true},
}
const TAPS_PER_S := 3.0
const STEP := 0.25
const PHASE_GAP := 30.0
const SAVE_WINDOW := 30.0


func m9() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var line: LineView = main.line_view(0)
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	var field: Battlefield = main.get_node("%Battlefield")
	var segs := GameState.lines[0].segments

	var names := []
	for i in 3:
		var sv := line.segment_view(i)
		names.append((sv.find_child("Name", true, false) as Label).text)
	t.check(names == ["FRAME", "CORE", "ARMS"], "stations named by type %s" % [names])
	var icons := []
	for i in 3:
		icons.append((line.segment_view(i).find_child("Stat", true, false) as TextureRect).texture.resource_path.get_file())
	t.check(icons == ["life.png", "credits_s.png", "damage.png"], "stat icons %s" % [icons])
	await t.shot("m9_fresh")

	var build: Button = _build_button(line, 0)
	t.check(build.disabled and build.theme_type_variation == &"PriceButton", "unaffordable build: normal button, dim price")
	GameState.scrap = 100.0
	await t.frames(2)
	t.check(not build.disabled and build.theme_type_variation == &"LitButton" and Price.color(build) == Price.ON, "affordable build: lit, white price")
	for i in 3:
		await t.click(_build_button(line, i))

	GameState.yard_workers = 2
	var tap := GameState.tap_scrap()
	var expect := GameState.stat("scrap_per_tap") + GameState.stat("tap_yard_share") * 2.0 * GameState.yard_chunk() / GameState.stat("worker_interval")
	t.check(is_equal_approx(tap, expect) and tap > GameState.stat("scrap_per_tap"), "pile tap scales with the yard (%.1f)" % tap)
	GameState.yard_workers = 0

	GameState.credits = 1e9
	for i in 3:
		GameState.buy_upgrade("tier_frame")
	var cost := GameState.tier_apply_cost(0, 0)
	var sum := 0.0
	for k in range(1, 4):
		sum += float(Data.tier("frame", k).apply_cost)
	t.check(is_equal_approx(cost, sum), "fit price is the sum of skipped tiers (%s)" % Fmt.num(cost))
	GameState.scrap = cost
	GameState.credits = 0.0
	await t.frames(1)
	var apply: Button = line.segment_view(0).get_node("Apply")
	t.check(apply.visible and Price.text(apply) == Fmt.num(cost) and apply.size.x == SegmentView.WIDTH, "fit takes the header, shows %s" % Price.text(apply))
	t.check(apply.theme_type_variation == &"LitRow", "affordable fit is lit")
	await t.shot("m9_fit")
	await t.click(apply)
	t.check(segs[0].tier == 3 and is_zero_approx(GameState.scrap), "⬆ fits Composite Strider in one tap")
	await t.frames(1)
	t.check(not apply.visible and line.segment_view(0).get_node("Header").visible, "fitted: the name is back")

	_reveal_all()
	GameState.credits = 1e9
	GameState.buy_upgrade("tier_plating")
	for i in 10:
		GameState.buy_upgrade("tap_damage")
	GameState.credits = 50.0
	await t.frames(1)
	await t.click(main.get_node("%Upgrades"))
	await t.frames(1)
	var effect := func(id: String) -> String: return (menu.row(id).find_child("Effect", true, false) as Label).text
	t.check(effect.call("tier_frame") == "LIFE 44 » 57 S", "frame tier row: %s" % effect.call("tier_frame"))
	t.check(effect.call("tier_core") == "PAY 1 » 2/S", "core tier row: %s" % effect.call("tier_core"))
	t.check(effect.call("tier_arms") == "DMG 1 » 2", "arms tier row: %s" % effect.call("tier_arms"))
	t.check(effect.call("tier_plating") == "LIFE +10 » +13 S", "plating tier row: %s" % effect.call("tier_plating"))
	t.check(effect.call("crew") == "WORKERS 3 » 4" and menu.row("crew").find_child("Pips", true, false).visible, "plain row: %s with level pips" % effect.call("crew"))
	var labelled := ["tap", "raises", "deploy_fee", "interval"].map(func(id: String) -> String: return effect.call(id))
	t.check(labelled == ["CREW 10% » 11%", "UP TO X1 » X1.5", "FEE X1 » X1.5", "EVERY 2S » 1.9S"], "labelled effect lines %s" % [labelled])
	t.check(effect.call("lines") == "LINE 2", "lines row: %s" % effect.call("lines"))
	t.check(not menu.row("tap_damage").visible, "maxed row hidden")
	var maxed: Label = menu.find_child("Maxed", true, false).find_child("List", true, false)
	t.check(maxed.is_visible_in_tree() and maxed.text == "HARDER HITS", "MAXED footer lists it (%s)" % maxed.text)
	var texts := main.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text) \
			+ main.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	t.check(not texts.any(func(x: String) -> bool: return x.split(" ").has("MAX")), "no MAX anywhere")
	var font: Font = preload("res://fonts/silkscreen.ttf")
	var missing := {}
	for x: String in texts:
		for i in x.length():
			if x[i] != "\n" and not font.has_char(x.unicode_at(i)):
				missing[x[i]] = true
	t.check(missing.is_empty(), "every shown character is in the font %s" % [missing.keys()])
	var flyers_node: Control = main.get_node("%Flyers")
	for c in flyers_node.get_children():
		c.free()
	Flyers.spawn(Flyers.Kind.SCRAP, Vector2(180, 400), 1.0)
	GameState.credits = 1e6
	await t.click(_buy(menu, "crew"))
	var above := func(d: CanvasItem) -> bool: return flyers_node.z_index + d.z_index > menu.z_index
	var discs := flyers_node.get_children()
	t.check(not above.call(discs[0]) and discs.slice(1).all(above), "factory discs below the menu, purchase discs above it")
	t.check(menu.get_child(0).color.a < 1.0, "menu background is see-through")
	await t.wait(0.2)
	await t.shot("m9_menu")
	await t.click(main.get_node("%Upgrades"))

	GameState.wave = 5
	GameState.wave_hp = GameState.wave_max_hp()
	await t.frames(2)
	var hp: Label = field.find_child("HpLabel", true, false)
	var dps: Label = field.find_child("DpsLabel", true, false)
	t.check(hp.text == "WAVE 6" and dps.text.ends_with(" DMG/S"), "wave bar in plain words: %s / %s" % [hp.text, dps.text])
	var flyers: Control = main.get_node("%Flyers")
	t.check(flyers.z_index < hp.z_index and flyers.z_index < (main.get_node("%Hud")._credits as Label).z_index, "discs fly behind HUD and wave bar text")
	t.check(flyers.z_index < main.get_node("%Settings").z_index, "and below the overlays")

	var unlock: Button = main.find_child("UnlockLine", true, false)
	GameState.credits = 0.0
	await t.frames(2)
	t.check(unlock.size.y == Main.UNLOCK_SMALL.y, "UNLOCK LINE compact while unaffordable (%d)" % unlock.size.y)
	GameState.credits = 1e9
	await t.frames(2)
	t.check(unlock.size.y >= 44.0 and unlock.theme_type_variation == &"LitButton", "full size and lit when affordable")
	var heights := [field.size.y]
	for i in 3:
		GameState.buy_upgrade("lines")
		await t.frames(2)
		heights.append(field.size.y)
	t.check(heights.all(func(h: float) -> bool: return h == Battlefield.HEIGHT), "battlefield stays 160 as lines are added %s" % [heights])
	var slot := unlock.get_parent() as Control
	t.check(slot.get_index() == GameState.lines.size() and slot == main.get_node("%Lines").get_child(-1)
			and unlock.position.y == Main.UNLOCK_GAP and slot.size.y == unlock.size.y + 2.0 * Main.UNLOCK_GAP,
			"UNLOCK LINE sits below the lines, gaps above and below")
	var l0: LineView = main.line_view(0)
	var l1: LineView = main.line_view(1)
	t.check(is_equal_approx(l1.position.y, l0.get_rect().end.y), "lines stack with no gap (%d, %d)" % [l0.get_rect().end.y, l1.position.y])

	await _fresh()
	main = t.get_tree().current_scene
	GameState.scrap = 1000.0
	GameState.credits = 300.0
	for i in 3:
		await t.click(_build_button(main.line_view(0), i))
	_reveal_all()
	GameState.debug_spawn_mechs(4)
	await t.frames(30)
	await t.shot("m9_revealed")
	await _sizes("m9_revealed")
	GameState.stalled_once = true
	GameState.credits = 1e9
	GameState.buy_upgrade("lines")
	GameState.buy_upgrade("tier_plating")
	GameState.credits = 5000.0
	await t.frames(30)
	await t.shot("m9_two_lines")
	await _sizes("m9_two_lines")


func _sizes(shot_name: String) -> void:
	if t.shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var window := t.get_window()
	var base := window.size
	for v: Array in [["tall", Vector2i(360, 780)], ["2x", Vector2i(720, 1280)]]:
		window.size = v[1]
		await t.frames(10)
		await t.shot("%s_%s" % [shot_name, v[0]])
	window.size = base
	await t.frames(5)


func tune() -> void:
	t.get_tree().current_scene.free()
	GameState.time_scale = 0.0
	var args := OS.get_cmdline_user_args()
	var only := args[args.find("--profile") + 1] if args.has("--profile") else ""
	var runs := {}
	for key: String in PROFILES:
		if only.is_empty() or key == only:
			runs[key] = _tune_run(PROFILES[key], key == only or (only.is_empty() and key == "baseline"))
	print("  profile    nuke   bounty  starved phases  gap  fit1  final  maxed  taps  work")
	for key: String in runs:
		var r: Dictionary = runs[key]
		print("  %-9s %5.1f   %4.0f%%    %4.1f%%  %3d  %4.0f  %4.0f  %5.0f  %5.1f  %4.0f%%  %3.0f%%" % [
			key, r.time / 60.0, r.bounty * 100.0, r.starved * 100.0, r.phases, r.gap, r.first_fit, r.final_wait,
			r.first_maxed / 60.0, r.tap_scrap * 100.0, r.tap_work * 100.0])
	for key: String in runs:
		var r: Dictionary = runs[key]
		t.check(r.over and r.time >= 1800.0 and r.time <= 3600.0, "%s: nuke at %.1f min" % [key, r.time / 60.0])
	if not runs.has("baseline"):
		GameState.new_game()
		return
	var base: Dictionary = runs.baseline
	t.check(base.first_worker < 240.0, "first worker at %.1f min" % (base.first_worker / 60.0))
	t.check(base.bounty >= 0.25 and base.bounty <= 0.4, "bounties %.0f%% of credits" % (base.bounty * 100.0))
	t.check(base.starved >= 0.05 and base.starved <= 0.15 and base.phases >= 3, "scrap short %.1f%% of the run in %d phases" % [base.starved * 100.0, base.phases])
	t.check(base.empty_windows == 0, "every 5 min window has buys (%d without)" % base.empty_windows)
	t.check(base.gap <= 120.0, "longest wait between buys %.0f s" % base.gap)
	t.check(base.first_fit <= 180.0, "first tier fit at %.0f s" % base.first_fit)
	t.check(base.final_wait <= 90.0, "final wait %.0f s" % base.final_wait)
	t.check(base.first_maxed >= 1200.0, "first regular row maxed at %.1f min" % (base.first_maxed / 60.0))
	if runs.size() < PROFILES.size():
		GameState.new_game()
		return
	t.check(absf(runs.field.time / base.time - 1.0) <= 0.2, "all-battlefield taps within 20%% of baseline (%.2f×)" % (runs.field.time / base.time))
	t.check(runs.quit10.time >= base.time * 1.1, "stopping taps at 10 min costs %.0f%% more time" % ((runs.quit10.time / base.time - 1.0) * 100.0))
	t.check(runs.no_arms.time > base.time, "fitting Arms beats not fitting them (%.1f vs %.1f min)" % [base.time / 60.0, runs.no_arms.time / 60.0])
	var gain := 0.0
	var gain_fit := ""
	for fit: String in base.l1_fits:
		var d: float = runs.no_pause.l1_fits.get(fit, INF) - base.l1_fits[fit]
		if d > gain:
			gain = d
			gain_fit = fit
	t.check(gain >= 60.0, "pausing gets a fit sooner (%s by %.0f s)" % [gain_fit.trim_prefix("apply L1 "), gain])
	t.check(runs.no_pause.time <= base.time * 1.1 and runs.no_pause.gap <= 150.0, "never pausing isn't stuck: %.1f vs %.1f min, longest wait %.0f s" % [runs.no_pause.time / 60.0, base.time / 60.0, runs.no_pause.gap])
	GameState.new_game()


func _tune_run(p: Dictionary, verbose: bool) -> Dictionary:
	GameState.new_game()
	var tps: float = p.get("taps", TAPS_PER_S)
	var r := {
		"credits": {"fee": 0.0, "payout": 0.0, "bounty": 0.0},
		"scrap": {"tap": 0.0, "yard": 0.0, "salvage": 0.0, "kill": 0.0},
		"work": {"tap": 0.0},
		"field_acc": 0.0,
		"buys": [],
		"events": [],
		"maxed": {},
	}
	var on_deploy := func(m: MechState) -> void: r.credits.fee += m.deploy_fee
	var on_income := func(_m: MechState, c: float) -> void: r.credits.payout += c
	var on_bounty := func(b: float) -> void: r.credits.bounty += b
	var on_died := func(_m: MechState, s: float) -> void: r.scrap.salvage += s
	var on_kill := func(_i: int, s: float) -> void: r.scrap.kill += s
	GameState.mech_deployed.connect(on_deploy)
	GameState.mech_income.connect(on_income)
	GameState.wave_cleared.connect(on_bounty)
	GameState.mech_died.connect(on_died)
	GameState.enemy_killed.connect(on_kill)
	var taps := 0.0
	var starved_t := 0.0
	var phases := []
	var seen := {}
	while not GameState.run_over and GameState.run_time < 5400.0:
		if GameState.run_time < p.get("stop", INF):
			taps += tps * STEP
		while taps >= 1.0:
			taps -= 1.0
			_bot_tap(p, r)
		if fmod(GameState.run_time, 1.0) < STEP * 0.5:
			_bot_manage(p, r)
		var yard_before := GameState.yard_chunks
		var chunk := GameState.yard_chunk()
		GameState.advance(STEP)
		r.scrap.yard += (GameState.yard_chunks - yard_before) * chunk
		if GameState.starved():
			starved_t += STEP
			if phases.is_empty() or GameState.run_time - phases[-1][1] > PHASE_GAP:
				phases.append([GameState.run_time, GameState.run_time])
			phases[-1][1] = GameState.run_time
		var minute := int(GameState.run_time / 60.0)
		if verbose and not seen.has(minute):
			seen[minute] = true
			print("  %3d min  cr %s (%s)  scrap %s (%s)  wave %d  dps %s  field %d  lines %d  tiers %s" % [
				minute, Fmt.num(GameState.credits), Fmt.rate(GameState.credits_rate),
				Fmt.num(GameState.scrap), Fmt.rate(GameState.scrap_rate), GameState.wave + 1, Fmt.num(GameState.field_dps()),
				GameState.field.size(), GameState.lines.size(),
				Data.line_slots().map(func(k: String) -> int: return GameState.unlocked_tier(k) + 1)])
	for c: Array in [[GameState.mech_deployed, on_deploy], [GameState.mech_income, on_income], [GameState.wave_cleared, on_bounty],
			[GameState.mech_died, on_died], [GameState.enemy_killed, on_kill]]:
		(c[0] as Signal).disconnect(c[1])
	var end := GameState.run_time
	if verbose:
		for e: Array in r.events:
			print("  %5.1f min  %s" % [e[0] / 60.0, e[1]])
		print("  credits %s  scrap %s" % [_shares(r.credits), _shares(r.scrap)])
		print("  scrap phases %s" % [phases.map(func(ph: Array) -> String: return "%.1f-%.1f" % [ph[0] / 60.0, ph[1] / 60.0])])
	var buys: Array = r.buys
	var gap := 0.0
	var final_wait := 0.0
	for i in range(1, buys.size()):
		gap = maxf(gap, buys[i][0] - buys[i - 1][0])
		if buys[i][1] == "final_arms":
			final_wait = buys[i][0] - buys[i - 1][0]
	var empty_windows := 0
	for w in int(end / 300.0):
		if not buys.any(func(b: Array) -> bool: return b[0] >= w * 300.0 and b[0] < (w + 1) * 300.0):
			empty_windows += 1
	var fits: Array = r.events.filter(func(e: Array) -> bool: return e[1].begins_with("apply"))
	var hires: Array = r.events.filter(func(e: Array) -> bool: return e[1].begins_with("hire"))
	var worker_work := 0.0
	for line in GameState.lines:
		for s in line.segments:
			worker_work += s.chunks * GameState.stat("worker_chunk")
	var credits_total: float = r.credits.values().reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	var scrap_total: float = r.scrap.values().reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	return {
		"over": GameState.run_over,
		"time": end,
		"bounty": r.credits.bounty / credits_total,
		"starved": starved_t / end,
		"phases": phases.filter(func(ph: Array) -> bool: return ph[1] - ph[0] >= 10.0).size(),
		"gap": gap,
		"empty_windows": empty_windows,
		"first_fit": fits[0][0] if fits.size() else INF,
		"first_worker": hires[0][0] if hires.size() else INF,
		"final_wait": final_wait,
		"first_maxed": r.maxed.values().min() if r.maxed.size() else INF,
		"l1_fits": _first_times(fits.filter(func(e: Array) -> bool: return e[1].begins_with("apply L1 "))),
		"tap_scrap": r.scrap.tap / scrap_total,
		"tap_work": r.work.tap / maxf(r.work.tap + worker_work, 1.0),
	}


func _first_times(events: Array) -> Dictionary:
	var d := {}
	for e: Array in events:
		if not d.has(e[1]):
			d[e[1]] = e[0]
	return d


func _shares(d: Dictionary) -> String:
	var total: float = d.values().reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	return " ".join(d.keys().map(func(k: String) -> String: return "%s %.0f%%" % [k, d[k] / maxf(total, 1.0) * 100.0]))


func _bot_tap(p: Dictionary, r: Dictionary) -> void:
	if GameState.revealed() and p.get("field", 0.0) > 0.0:
		r.field_acc += p.field
		if r.field_acc >= 1.0:
			r.field_acc -= 1.0
			GameState.tap_wave()
			return
	if GameState.scrap < maxf(30.0, r.get("want", 0.0)) or GameState.starved():
		r.scrap.tap += GameState.tap_scrap()
		GameState.tap_pile()
		return
	var best: SegmentState = null
	var best_at := [-1, -1]
	for li in GameState.lines.size():
		var line := GameState.lines[li]
		if line.paused or not line.is_complete():
			continue
		for i in line.segments.size():
			var s := line.segments[i]
			if s.built and not s.bar_full() and (best == null or s.work / s.bar_size() < best.work / best.bar_size()):
				best = s
				best_at = [li, i]
	if best == null:
		r.scrap.tap += GameState.tap_scrap()
		GameState.tap_pile()
		return
	var before := best.work
	GameState.tap_segment(best_at[0], best_at[1])
	r.work.tap += best.work - before


func _bot_manage(p: Dictionary, r: Dictionary) -> void:
	var now := GameState.run_time
	for li in GameState.lines.size():
		for i in GameState.lines[li].segments.size():
			if not GameState.lines[li].segments[i].built and GameState.build_segment(li, i):
				r.events.append([now, "build L%d %s" % [li + 1, GameState.lines[li].segments[i].type_id]])
	var pending := INF
	var nuke_ready: bool = GameState.unlocked_tier("arms") > GameState.top_tier("arms")
	for li in GameState.lines.size():
		for i in GameState.lines[li].segments.size():
			var s := GameState.lines[li].segments[i]
			if not GameState.can_apply_tier(li, i):
				continue
			if nuke_ready:
				if li != 0:
					continue
			elif p.get("no_arms", false) and s.type_id == "arms":
				continue
			var cost := GameState.tier_apply_cost(li, i)
			if GameState.apply_tier(li, i):
				r.events.append([now, "apply L%d %s" % [li + 1, s.tier_data().part]])
				r.buys.append([now, "apply"])
			else:
				pending = minf(pending, cost)
	r.want = pending if pending < INF else 0.0
	var short := pending - GameState.scrap
	var save := pending < INF and GameState.scrap_rate * 60.0 < short and GameState.scrap_gain_rate * SAVE_WINDOW >= short
	if nuke_ready:
		save = GameState.lines[0].segments[2].tier <= GameState.top_tier("arms")
	if p.get("no_pause", false):
		save = false
	for li in GameState.lines.size():
		if GameState.lines[li].paused != save:
			GameState.toggle_pause(li)
	while true:
		var options := []
		for li in GameState.lines.size():
			if GameState.lines[li].workers < GameState.lines[li].worker_slots():
				options.append([GameState.worker_cost(li), "hire", li])
		if GameState.yard_workers < GameState.yard_slots():
			options.append([GameState.yard_worker_cost(), "yard"])
		for row: Dictionary in Data.upgrade_list:
			if GameState.upgrade_visible(row.id) and not GameState.upgrade_maxed(row.id) and not GameState.upgrade_locked(row.id):
				options.append([GameState.upgrade_cost(row.id), "buy", row.id])
		options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		if options.is_empty() or options[0][0] > GameState.credits:
			return
		var o: Array = options[0]
		match o[1]:
			"hire":
				GameState.hire_worker(o[2])
				r.buys.append([now, "hire"])
				if not r.events.any(func(e: Array) -> bool: return e[1].begins_with("hire")):
					r.events.append([now, "hire first worker"])
			"yard":
				GameState.hire_yard_worker()
				r.buys.append([now, "yard"])
			"buy":
				GameState.buy_upgrade(o[2])
				r.buys.append([now, o[2]])
				var row := Data.upgrade_row(o[2])
				if row.get("kind", "") != "" or o[2] in ["lines", "kill_scrap"]:
					r.events.append([now, "%s %d" % [o[2], GameState.level(o[2])]])
				elif GameState.upgrade_maxed(o[2]):
					r.maxed[o[2]] = now
					r.events.append([now, "%s maxed" % o[2]])


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


func ui() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var font: Font = ThemeDB.get_project_theme().default_font
	t.check(absf(font.get_ascent(16) - 5.0 - font.get_height(16) / 2.0) < 0.5, "caps centered in the line box (ascent %d, height %d)" % [font.get_ascent(16), font.get_height(16)])
	_reveal_all()
	GameState.stalled_once = true
	GameState.credits = 5000.0
	GameState.scrap = 60.0
	GameState.buy_upgrade("lines")
	GameState.credits = 5000.0
	GameState.build_segment(0, 0)
	GameState.buy_upgrade("tier_frame")
	await t.frames(3)
	var buttons := main.find_children("*", "Button", true, false).filter(func(b: Button) -> bool:
		return b.has_node("Price") and b.is_visible_in_tree())
	t.check(buttons.size() >= 7, "price buttons on screen (%d)" % buttons.size())
	for b: Button in buttons:
		var box: HBoxContainer = b.get_node("Price")
		var first: Control = box.get_child(0)
		var last: Control = box.get_child(-1)
		var group_x := (first.get_global_rect().position.x + last.get_global_rect().end.x) / 2.0
		var label: Label = box.get_node("Cost/Text")
		var center := b.get_global_rect().get_center()
		t.check(absf(group_x - center.x) <= 1.0 and absf(label.get_global_rect().get_center().y - center.y) <= 1.0,
				"%s: icon + price centered (dx %.1f, dy %.1f)" % [b.name, group_x - center.x, label.get_global_rect().get_center().y - center.y])
		var icon: TextureRect = box.get_node("Cost/Icon")
		var credits: bool = b.name in ["Hire", "HireYard", "Buy", "UnlockLine"]
		var icons: Array = Price.ICONS_SMALL if b.get_meta("row", false) else Price.ICONS
		t.check(icon.texture == icons[Flyers.Kind.CREDITS if credits else Flyers.Kind.SCRAP] and icon.get_index() == label.get_index() - 1 and label.get_index() == label.get_parent().get_child_count() - 1,
				"%s: %s icon right before the price" % [b.name, "coin" if credits else "nut"])
	var yard_hire: Button = main.find_child("HireYard", true, false)
	var upgrades: Button = main.get_node("%Upgrades")
	var line_hire: Button = main.line_view(0).hire_button()
	var fit: Button = main.line_view(0).segment_view(0).get_node("Apply")
	var unlock: Button = main.find_child("UnlockLine", true, false)
	var widest := [[fit, "52.3K", ""], [line_hire, "21.8K", ""], [yard_hire, "21.8K", ""], [unlock, "84.5K", "+ LINE 5"],
			[main.line_view(1).segment_view(0).get_node("Build"), "200", ""]]
	for w: Array in widest:
		var b: Button = w[0]
		Price.show(b, w[1], false, w[2])
		var need: float = (b.get_node("Price") as Control).get_combined_minimum_size().x
		var room := b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
		t.check(b.is_visible_in_tree() and need <= room, "%s: widest price %s fits (%d of %d)" % [b.name, w[1], need, room])
	t.check(yard_hire.size == line_hire.size and yard_hire.get_meta("row", false), "yard hire is a crew bar button like the line hire (%s)" % yard_hire.size)
	var crew: Label = main.line_view(1).get_node("Crew")
	var crew_w := crew.get_theme_font("font").get_string_size("LINE CREW 99/99", HORIZONTAL_ALIGNMENT_LEFT, -1, crew.get_theme_font_size("font_size")).x
	t.check(crew_w <= crew.size.x, "LINE CREW 99/99 fits a tagged line's crew bar (%d of %d)" % [crew_w, crew.size.x])
	var up_rect := upgrades.get_global_rect()
	t.check(up_rect == Rect2(6, 590, 348, 44), "UPGRADES spans the bottom (%s)" % up_rect)
	var build: Button = main.line_view(1).segment_view(0).get_node("Build")
	var pad: Control = main.line_view(1).segment_view(0).get_child(2)
	t.check(pad.get_global_rect().position.x == build.get_global_rect().position.x and pad.size.x == build.size.x, "build button as wide as its pad (%d)" % pad.size.x)
	var crossing := []
	for slots in range(3, 14):
		var left_end := SegmentView.worker_x(slots - 1 - (slots + 1) % 2, slots) + SegmentView.WORKER_W
		var right_start := SegmentView.worker_x(slots - 1 - slots % 2, slots)
		if left_end > right_start:
			crossing.append(slots)
	t.check(crossing.is_empty(), "station crews never cross behind the mech, 3..13 per station %s" % [crossing])
	await t.shot("ui_lines")

	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	var pile: Control = main.find_child("Pile", true, false)
	await t.click(upgrades)
	var bar_top: float = main.get_node("%Bar").get_global_rect().position.y
	t.check(menu.visible and menu.get_global_rect().end.y == bar_top, "menu reaches down to the bottom bar")
	var list: ScrollContainer = menu.get_child(1).get_child(0)
	t.check(list.get_global_rect().end.y <= bar_top - UpgradeMenu.MARGIN, "rows end above the bar")
	var wide_rows := func() -> Array:
		var wide := []
		for id: String in Data.upgrade_list.map(func(r: Dictionary) -> String: return r.id):
			var row := menu.row(id)
			if row.get_combined_minimum_size().x > menu.size.x - 2 * UpgradeMenu.MARGIN:
				wide.append("%s %d" % [id, row.get_combined_minimum_size().x])
		return wide
	var too_wide: Array = wide_rows.call()
	t.check(too_wide.is_empty() and list.size.x == menu.size.x - 2 * UpgradeMenu.MARGIN, "every row fits the menu (list %d) %s" % [list.size.x, too_wide])
	var scrap := GameState.scrap
	await t.click(pile)
	t.check(GameState.scrap == scrap, "menu blocks the pile")
	t.check(menu.get_child(0).color.a >= 0.9 and menu.row("tap").self_modulate.a == 1.0, "menu nearly opaque, rows opaque")
	var groove := menu.track()
	t.check(menu.thumb().has_area() and menu.thumb().position.y == groove.position.y and groove.end.x < menu.size.x and groove.position.x > list.get_rect().end.x,
			"list scrolls: thumb at the top of the right margin (%s)" % menu.thumb())
	await t.shot("ui_menu")
	list.scroll_vertical = 100000
	await t.frames(2)
	t.check(menu.thumb().end.y == groove.end.y, "scrolled to the end: thumb at the bottom")
	await t.shot("ui_menu_end")
	GameState.credits = 1e30
	for r: Dictionary in Data.upgrade_list:
		if r.get("kind", "") == "" and r.id != "lines":
			while GameState.level(r.id) < int(r.max_level) - 1:
				GameState.buy_upgrade(r.id)
	await t.frames(2)
	too_wide = wide_rows.call()
	t.check(too_wide.is_empty(), "every row fits one level before its cap (widest effect lines) %s" % [too_wide])
	await t.click(upgrades)
	t.check(not menu.visible, "CLOSE on top of the menu closes it")

	var settings: SettingsOverlay = main.get_node("%Settings")
	await t.click(main.get_node("%Hud").get_node("SettingsButton"))
	await t.click(settings.find_child("CreditsButton", true, false))
	var credits: Control = settings.find_child("Credits", true, false)
	var lines := credits.find_children("*", "Label", true, false)
	var wide := lines.filter(func(l: Label) -> bool: return l.get_minimum_size().x > credits.size.x)
	t.check(credits.is_visible_in_tree() and lines.size() >= 12 and wide.is_empty(), "credits: %d lines, all fit (%s)" % [lines.size(), wide.map(func(l: Label) -> String: return l.text)])
	t.check(settings.get_global_rect().encloses(credits.get_global_rect()), "credits inside the screen")
	await t.shot("ui_credits")
	await t.click(settings.find_child("LicensesButton", true, false))
	var licenses: Control = settings.find_child("Licenses", true, false)
	var license_scroll: ScrollContainer = licenses.find_child("Scroll", true, false)
	var text := SettingsOverlay.license_text()
	await t.frames(2)
	t.check(licenses.visible and text.length() > 50000 and "FreeType" in text and "Permission is hereby granted" in text,
			"licenses popup: Godot license + third-party notices (%d chars, %d labels)" % [text.length(), license_scroll.get_child(0).get_child_count()])
	license_scroll.scroll_vertical = 100000
	await t.frames(2)
	t.check(license_scroll.scroll_vertical > 10000, "license text scrolls (%d px)" % license_scroll.scroll_vertical)
	license_scroll.scroll_vertical = 0
	await t.frames(2)
	await t.shot("ui_licenses")
	await t.click(licenses.find_child("LicensesClose", true, false))
	t.check(not licenses.visible and credits.is_visible_in_tree(), "BACK returns to credits")
	await t.click(settings.find_child("Close", true, false))
	t.check(settings.visible and not credits.is_visible_in_tree() and settings.find_child("AudioButton", true, false).is_visible_in_tree(), "BACK returns to settings")
	await t.click(settings.find_child("Close", true, false))
	t.check(not settings.visible, "CLOSE closes settings")


func progression() -> void:
	await _fresh()
	Reveal.instant = false
	var main := t.get_tree().current_scene
	var yard: Scrapyard = t.node("Scrapyard")
	var field: Battlefield = t.node("Battlefield")
	var rail: ScrollRail = t.node("Rail")
	var bar: Control = t.node("Bar")
	var column: Control = t.node("Column")
	var hud: Control = t.node("Hud")
	var line: LineView = main.line_view(0)
	var unlock: Control = main.find_child("UnlockSlot", true, false)
	var yard_hire: Control = yard.get_node("HireYard")
	var col := column.get_global_rect()
	t.check(not field.visible and not line.visible and not rail.visible and not bar.visible and not unlock.visible,
			"new game: battlefield, line, scroll bar, UPGRADES, UNLOCK LINE hidden")
	t.check(absf(yard.get_global_rect().get_center().y - col.get_center().y) <= 1.0 and absf(yard.get_global_rect().get_center().x - 180.0) <= 1.0,
			"only the scrapyard, centered (%s)" % yard.get_global_rect())
	t.check(not hud.get_node("Mechs").visible and not hud.get_node("MechsRate").visible, "HUD: scrap only")
	await t.shot("start_pile")
	var pile: Control = yard.pile()
	for i in 9:
		await t.click(pile)
	await t.frames(2)
	t.check(not line.visible and not GameState.shown("factory"), "9 scrap: still only the pile")
	await t.click(pile)
	await t.frames(2)
	t.check(GameState.shown("factory") and line.visible and line.modulate.a < 1.0, "scrap for the first station: the line fades in")
	await t.wait(Reveal.SLIDE_TIME / 2.0)
	var mid := yard.get_global_rect().end.y
	t.check(mid > yard.get_global_rect().size.y and mid < col.end.y, "the yard slides down (bottom at %d)" % mid)
	await t.shot("start_factory_mid")
	await t.wait(Reveal.SLIDE_TIME)
	t.check(line.modulate.a == 1.0 and yard.get_global_rect().end.y == col.end.y and line.get_global_rect().end.y == yard.get_global_rect().position.y,
			"yard at the bottom, the line right above it")
	await t.shot("start_factory")

	GameState.scrap = 45.0
	for i in 3:
		await t.click(_build_button(line, i))
	GameState.debug_spawn_mechs(1)
	await t.frames(2)
	t.check(field.visible and field.size.y < Battlefield.HEIGHT and rail.visible and rail.size.x < ScrollRail.WIDTH, "first mech: battlefield and scroll bar slide in")
	await t.wait(Reveal.SLIDE_TIME / 2.0)
	await t.shot("start_field_mid")
	await t.wait(Reveal.SLIDE_TIME)
	t.check(field.size.y == Battlefield.HEIGHT and field.get_global_rect().position.y == col.position.y and rail.size.x == ScrollRail.WIDTH,
			"battlefield attached under the HUD, scroll bar in")
	t.check(yard.get_global_rect().end.y == col.end.y and line.get_global_rect().end.y == yard.get_global_rect().position.y
			and line.get_global_rect().position.y > field.get_global_rect().end.y,
			"factory and yard stay at the bottom, the gap sits between battlefield and factory")
	t.check(hud.get_node("Mechs").visible and hud.get_node("Mechs").self_modulate.a == 1.0, "HUD: mechs and credits faded in")
	t.check(not bar.visible and not line.hire_button().visible and not yard_hire.visible and not unlock.visible, "nothing affordable: no crew bars, UPGRADES, UNLOCK LINE")
	await t.shot("start_field")

	GameState.credits = GameState.yard_worker_cost()
	await t.frames(2)
	t.check(yard_hire.visible and not line.hire_button().visible, "yard crew bar at the yard hire price, line crew bar not yet")
	await t.wait(Reveal.TIME + 0.1)
	GameState.credits = GameState.worker_cost(0)
	await t.wait(Reveal.TIME + 0.1)
	t.check(line.hire_button().visible and line.segment_view(0).position.y == LineView.CREW_H and not bar.visible, "line crew bar at the line hire price")
	GameState.credits = 60.0
	await t.frames(2)
	t.check(GameState.affordable_upgrades() > 0 and bar.visible and bar.size.y < Main.BAR_H, "UPGRADES rises at the first affordable upgrade")
	await t.wait(Reveal.TIME + 0.1)
	t.check(bar.size.y == Main.BAR_H and (t.node("Upgrades") as Control).get_global_rect().end.y == 634.0, "UPGRADES in place")
	GameState.credits = GameState.upgrade_cost("lines")
	await t.wait(Reveal.TIME + 0.1)
	t.check(unlock.visible and unlock.size.y == Main.UNLOCK_GAP * 2.0 + Main.UNLOCK_BIG.y, "UNLOCK LINE grows in once affordable")
	GameState.credits = 0.0
	await t.frames(2)
	t.check(bar.visible and unlock.visible and yard_hire.visible and line.hire_button().visible, "revealed parts stay when credits drop")
	await t.shot("start_buying")

	Save.save_game()
	t.get_tree().reload_current_scene()
	await t.frames(3)
	main = t.get_tree().current_scene
	t.check((t.node("Bar") as Control).size.y == Main.BAR_H and (t.node("Battlefield") as Control).size.y == Battlefield.HEIGHT
			and main.find_child("UnlockSlot", true, false).visible, "reload: everything seen is in place at once")
	var old := GameState.to_dict()
	old.erase("seen")
	GameState.from_dict(old)
	t.check(GameState.REVEALS.all(GameState.shown), "old save with mechs built: everything counts as seen")
	old.mechs_built = 0
	GameState.from_dict(old)
	t.check(GameState.seen.is_empty(), "old save before the first mech: nothing seen yet")

	Save.reset_run()
	await t.frames(4)
	t.check(not (t.node("Battlefield") as Control).visible and not (t.node("Bar") as Control).visible and not t.get_tree().current_scene.line_view(0).visible,
			"START AGAIN: back to the pile alone")
	Reveal.instant = true


func pane() -> void:
	await _fresh()
	_reveal_all()
	await t.frames(2)
	var main := t.get_tree().current_scene
	var scroll: ScrollContainer = t.node("Scroll")
	var column: Control = t.node("Column")
	var content: Control = t.node("Content")
	var rail: ScrollRail = t.node("Rail")
	var field: Battlefield = t.node("Battlefield")
	var yard: Scrapyard = t.node("Scrapyard")
	var lines: Control = t.node("Lines")
	var field_pin := rail.pin_button(0)
	var yard_pin := rail.pin_button(1)
	t.check(rail.size == Vector2(20, column.size.y) and rail.get_global_rect().end.x == 360.0 and column.size.x == 340.0, "rail 20 px right of the pane, full height (%s)" % rail.size)
	t.check(rail.state(0) == ScrollRail.Pin.SHOWN and rail.state(1) == ScrollRail.Pin.SHOWN and not rail._thumb().has_area(), "one line: everything fits, no thumb, both pins plain")

	_reveal_all()
	GameState.stalled_once = true
	GameState.credits = 1e9
	for i in 4:
		GameState.buy_upgrade("lines")
	GameState.buy_upgrade("tier_plating")
	GameState.credits = 0.0
	await t.frames(3)
	var line: LineView = main.line_view(0)
	var right := line.segment_view(3).position.x + SegmentView.WIDTH
	t.check(line.segment_view(0).position.x == LineView.PAUSE_W and right == line.size.x, "4 stations fill the line next to the rail (%d..%d)" % [line.segment_view(0).position.x, right])
	var spans := []
	for i in 4:
		var h: Control = line.segment_view(i).get_node("Header")
		spans.append(Vector2(h.get_global_rect().position.x, h.get_global_rect().end.x))
	var apart := range(3).all(func(i: int) -> bool: return spans[i].y + LineView.HEADER_GAP <= spans[i + 1].x)
	t.check(apart and spans[3].y <= line.get_global_rect().end.x - LineView.HEADER_GAP and spans[0].x >= line.get_global_rect().position.x + LineView.PAUSE_W,
			"station headers stay inside the line, apart and off the rail (%s)" % [spans])
	var bar := scroll.get_v_scroll_bar()
	var bottom := int(bar.max_value - bar.page)
	t.check(bottom > 300 and rail._thumb().has_area(), "5 lines scroll (%d px), thumb shown" % bottom)
	t.check(scroll.scroll_vertical == 0 and rail.state(0) == ScrollRail.Pin.SHOWN and rail.state(1) == ScrollRail.Pin.AWAY, "starts at the top: field in view, yard away")
	t.check(yard_pin.theme_type_variation == &"AwayButton" and field_pin.theme_type_variation == &"", "away pin light as quick access, the other plain")
	t.check(Sound.presence.field == 1.0 and Sound.presence.yard == 0.0 and Sound.presence.factory > 0.0, "sound: field and lines present, yard hidden")
	GameState.scrap = 1e6
	GameState.credits = 1e6
	for i in 4:
		GameState.build_segment(0, i)
	GameState.buy_upgrade("tier_frame")
	GameState.credits = 0.0
	await t.frames(2)
	var fit: Button = line.segment_view(0).get_node("Apply")
	var hire := line.hire_button()
	var bar_edge := line.get_global_rect().position.y + LineView.CREW_H - 1.0
	var machine: Control = line.segment_view(0).get_child(1)
	t.check(fit.visible and fit.get_global_rect().position.y == bar_edge and hire.get_global_rect().end.y == bar_edge + 1.0
			and fit.get_global_rect().end.y == machine.get_global_rect().position.y + 1.0,
			"hire and fit share the crew bar's bottom edge, fit shares the machine's top edge")
	var strip_edge := line.get_global_rect().position.x + LineView.PAUSE_W - 1.0
	t.check(hire.get_global_rect().end.x == column.size.x + 1.0 and fit.get_global_rect().position.x == strip_edge
			and line.segment_view(3).get_node("Apply").get_global_rect().end.x == column.size.x + 1.0,
			"hire and the last fit end on the rail seam, the first fit starts on the pause strip's edge")
	var tag: Label = line.get_node("Tag")
	var crew_label: Label = line.get_node("Crew")
	var text_row := func(l: Label) -> float: return l.position.y + (l.size.y - l.get_line_height()) / 2.0
	t.check(tag.size == LineView.TAG and tag.position.y == 3.0 and tag.position.y + tag.size.y == LineView.CREW_H - 3.0,
			"line tag 16x20, 2 px inside the bar's edges (%s at %d)" % [tag.size, tag.position.y])
	t.check(text_row.call(tag) == text_row.call(crew_label), "tag digit on the crew text's rows (%d, %d)" % [text_row.call(tag), text_row.call(crew_label)])
	await t.shot("pane_top")

	await t.click(yard_pin)
	await t.wait(ScrollRail.JUMP_TIME + 0.1)
	t.check(scroll.scroll_vertical == bottom and Sound.visible_share(yard) == 1.0 and rail.state(1) == ScrollRail.Pin.SHOWN, "quick access scrolls down to the yard")
	t.check(rail.state(0) == ScrollRail.Pin.AWAY and field_pin.theme_type_variation == &"AwayButton", "the field pin turns into quick access")
	t.check(Sound.presence.field == 0.0 and Sound.presence.yard == 1.0 and is_equal_approx(Sound._area_gain("field"), db_to_linear(Data.audio.areas.field.hidden_db)),
			"sound: field down to hidden_db, yard present")
	await t.shot("pane_bottom")

	await t.click(yard_pin)
	await t.frames(3)
	t.check(rail.pinned[1] and yard.get_parent() == column and yard.get_index() == column.get_child_count() - 1 and yard_pin.theme_type_variation == &"PinnedButton",
			"pinning the yard fixes it under the pane")
	await t.click(field_pin)
	await t.wait(ScrollRail.JUMP_TIME + 0.1)
	t.check(scroll.scroll_vertical == 0 and Sound.visible_share(yard) == 1.0 and Sound.visible_share(field) == 1.0, "back at the top, the pinned yard stays in view")
	await t.click(field_pin)
	await t.frames(3)
	t.check(rail.pinned[0] and field.get_parent() == column and field.get_index() == 0 and field.size.y == Battlefield.HEIGHT,
			"pinning the field fixes it above the pane (%d px)" % field.size.y)
	scroll.scroll_vertical = 100000
	await t.frames(2)
	t.check(Sound.visible_share(field) == 1.0 and Sound.visible_share(yard) == 1.0 and Sound.presence.factory > 0.0, "both pinned: the lines scroll between them")
	await t.shot("pane_pinned")
	await t.click(field_pin)
	await t.frames(3)
	t.check(not rail.pinned[0] and field.get_parent() == content and field.get_index() == 0 and scroll.scroll_vertical == 0 and rail.state(0) == ScrollRail.Pin.SHOWN,
			"unpinning the field puts it back on top of the pane, in view")
	await t.click(yard_pin)
	await t.frames(3)
	bottom = int(bar.max_value - bar.page)
	t.check(not rail.pinned[1] and yard.get_parent() == content and scroll.scroll_vertical == bottom, "unpinning the yard puts it back at the end, in view")

	var track := rail._track()
	var at := func(y: float) -> Vector2: return rail.global_position + Vector2(rail.size.x / 2.0, y)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at.call(track.position.y + 1.0)
	press.global_position = press.position
	t.get_viewport().push_input(press, true)
	await t.frames(1)
	t.check(scroll.scroll_vertical == 0, "pressing the track top scrolls to the top")
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = at.call(track.end.y - 1.0)
	move.global_position = move.position
	t.get_viewport().push_input(move, true)
	await t.frames(1)
	t.check(scroll.scroll_vertical == bottom, "dragging the thumb down scrolls to the bottom")
	var release := press.duplicate()
	release.pressed = false
	t.get_viewport().push_input(release, true)
	await t.frames(1)

	var flyers: Flyers = t.node("Flyers")
	Flyers.spawn(Flyers.Kind.CREDITS, Vector2(100, -40), 1.0, 1, true)
	var disc: Control = flyers.get_child(-1)
	t.check(flyers.clip == column.get_global_rect() and flyers.clip.has_point(disc.position), "discs from a scrolled-away source start at the pane edge (%s)" % disc.position)

	GameState.debug_spawn_mechs(3)
	await t.frames(3)
	var guide: IntroGuide = main.get_node("IntroGuide")
	var tip: Vector2 = guide.get("_tip") + guide.global_position
	var pin_rect := field_pin.get_global_rect()
	t.check(guide.text() == "TAP THE FIELD TO HIT THE WAVE" and tip.x == pin_rect.get_center().x and tip.y > pin_rect.end.y and tip.y < pin_rect.end.y + 8.0,
			"field hint points at the field pin while the field is away (%s)" % tip)

	rail.pin(0, true)
	rail.pin(1, true)
	await t.frames(3)
	rail.release()
	await t.frames(3)
	t.check(field.get_parent() == content and yard.get_parent() == content and scroll.scroll_vertical == 0, "the nuke unpins both and shows the field")


func art() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var nuke: Nuke = main.get_node("%Nuke")
	_reveal_all()
	GameState.stalled_once = true
	GameState.credits = 1e9
	GameState.scrap = 1e9
	GameState.buy_upgrade("tier_plating")
	for i in 2:
		GameState.buy_upgrade("lines")
	await t.frames(2)
	for li in GameState.lines.size():
		var segs := GameState.lines[li].segments
		for si in segs.size():
			GameState.build_segment(li, si)
			segs[si].tier = clampi(li * 2 + si % 2, 0, 4)
			GameState.hire_worker(li)
			if si % 2 == 0:
				GameState.hire_worker(li)
			var m := MechState.new()
			m.id = GameState.next_mech_id
			GameState.next_mech_id += 1
			for k in si + 1:
				m.parts[Data.line_slots()[k]] = clampi(li * 2 + k % 3, 0, 4)
			segs[si].mech = m
		segs[1].assembling = true
		segs[2].stall = SegmentState.Stall.NO_SCRAP
	GameState.scrap = 5.0
	GameState.wave = 26
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 24:
		var m := MechState.new()
		m.id = GameState.next_mech_id
		GameState.next_mech_id += 1
		m.parts = {"frame": rng.randi_range(0, 5), "core": rng.randi_range(0, 5), "arms": rng.randi_range(0, 4)}
		if rng.randf() < 0.6:
			m.parts["plating"] = rng.randi_range(0, 5)
		GameState.call("_deploy", m)
	GameState.time_scale = 1.0
	await t.wait(8.0)
	for i in GameState.field.size():
		var m: MechState = GameState.field[i]
		m.wear = m.lifetime * (0.85 if i == 5 else 0.1)
	await t.wait(1.0)
	await t.shot("art_field")
	await t.wait(0.5)
	await t.shot("art_field2")
	GameState.time_scale = 0.0
	(main.get_node("%Scroll") as ScrollContainer).scroll_vertical = 0
	await t.frames(5)
	await t.shot("art_factory")
	await t.frames(12)
	await t.shot("art_factory2")
	GameState.time_scale = 1.0
	var n := MechState.new()
	n.id = GameState.next_mech_id
	GameState.next_mech_id += 1
	n.parts = {"frame": 5, "core": 5, "arms": 5, "plating": 5}
	GameState.call("_deploy", n)
	for k: Array in [[1.0, "nuke_walk"], [3.2, "nuke_ready"], [0.9, "nuke_launch"], [1.2, "nuke_flash"], [0.9, "nuke_cloud"], [1.4, "nuke_cloud2"], [1.2, "nuke_sweep"], [1.4, "nuke_sweep2"]]:
		await t.wait(k[0])
		await t.shot(k[1])
	var start := Time.get_ticks_msec()
	while not nuke.card_visible() and Time.get_ticks_msec() - start < 20000:
		await t.frames(1)
	await t.wait(1.5)
	await t.shot("nuke_card")
	t.check(nuke.card_visible(), "nuke ends on the card")


const PERF_MECHS := 170
const PERF_FRAMES := 480


func field_perf() -> void:
	await _fresh(false)
	var main := t.get_tree().current_scene
	var field: Battlefield = main.get_node("%Battlefield")
	_reveal_all()
	GameState.wave = 26
	GameState.wave_hp = GameState.wave_max_hp()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_perf_fill(rng)
	await t.wait(4.0)
	t.check(is_equal_approx(t.get_process_delta_time(), 1.0 / 60.0), "run with --fixed-fps 60: each frame is 1/60 s of game time")
	for level in range(Effects.HIGH, Effects.LOW - 1, -1):
		Effects.level = level
		await t.wait(2.0)
		var stats := await _perf_measure(rng, PERF_FRAMES)
		print("  %s: %d mechs (%d drawn): %.2f ms/frame mean, %.2f ms p95, %d nodes" % [
			Data.effects.levels[level].name, GameState.field.size(), field.mech_count(), stats.mean_ms, stats.p95_ms, stats.nodes])
		t.check(field.mech_count() > 0, "field measured")
		await t.shot("field_perf_%d" % level)
	Effects.level = Effects.HIGH


func field() -> void:
	var settings_backup := FileAccess.get_file_as_string(Save.SETTINGS_PATH) if FileAccess.file_exists(Save.SETTINGS_PATH) else ""
	await _fresh(false)
	var main := t.get_tree().current_scene
	var field: Battlefield = main.get_node("%Battlefield")
	_reveal_all()
	GameState.debug_spawn_mechs(30)
	await t.frames(2)
	t.check(field.mech_count() == 24, "HIGH: 3 rows drawn (%d)" % field.mech_count())
	t.check(not main.line_view(0).get_node("Tag").visible, "one line: no line tag on the crew bar")

	var settings: SettingsOverlay = main.get_node("%Settings")
	settings.open()
	await t.frames(1)
	var row := settings.find_child("Effects", true, false)
	t.check(row != null and row.is_visible_in_tree(), "settings show an EFFECTS row")
	await t.shot("field_settings")
	var music_step := int(Sound.steps.music)
	await t.click(row.get_node("Down"))
	t.check(Effects.level == 1 and not Effects.auto, "EFFECTS - lowers the level and turns auto off")
	var saved := Save.load_settings()
	t.check(int(saved.get("effects", -1)) == 1 and saved.get("effects_auto") == false and int(saved.get("music", -1)) == music_step,
			"level saved next to the sound settings")
	Sound.set_step("music", music_step)
	t.check(int(Save.load_settings().get("effects", -1)) == 1, "saving sound settings keeps the level")
	await t.click(row.get_node("Down"))
	await t.click(row.get_node("Down"))
	t.check(Effects.level == Effects.LOW, "clamped at LOW")
	await t.frames(2)
	t.check(field.mech_count() == 8, "LOW: one row drawn (%d)" % field.mech_count())
	t.check(Effects.scaled(10, "debris") == 5 and Effects.value("smoke") == 0.0, "LOW: half debris, no damage smoke")
	await t.click(row.get_node("Up"))
	await t.frames(2)
	t.check(field.mech_count() == 16, "MED: two rows drawn (%d)" % field.mech_count())
	settings.close()

	Effects.level = Effects.HIGH
	Effects.auto = true
	for k in 300:
		Effects.sample(1.0 / 60.0)
	t.check(Effects.level == Effects.HIGH, "auto: 60 fps keeps the level")
	for k in 150:
		Effects.sample(1.0 / 25.0)
	t.check(Effects.level == 1 and Effects.auto, "auto: 5 s at 25 fps steps down once")
	Effects.level = Effects.HIGH

	GameState.time_scale = 0.0
	await t.frames(2)
	var crowd := field.crowd()
	t.check(crowd.count() == GameState.field.size() - 24, "undrawn mechs stand in the crowd (%d)" % crowd.count())
	GameState.debug_spawn_mechs(200)
	await t.frames(2)
	t.check(crowd.count() == 150, "HIGH: crowd capped at 150 (%d of %d mechs)" % [crowd.count(), GameState.field.size()])
	Effects.level = 1
	await t.frames(2)
	t.check(field.mech_count() == 16 and crowd.count() == 60, "MED: 16 drawn, crowd 60 (%d)" % crowd.count())
	Effects.level = Effects.LOW
	await t.frames(2)
	t.check(field.mech_count() == 8 and crowd.count() == 0, "LOW: no crowd")
	Effects.level = Effects.HIGH
	await t.frames(2)
	var in_crowd: MechState = GameState.field.filter(func(m: MechState) -> bool: return crowd.has(m.id)).front()
	in_crowd.wear = in_crowd.lifetime
	var before := crowd.count()
	GameState.advance(GameState.TICK)
	await t.frames(2)
	t.check(not crowd.has(in_crowd.id) and crowd.count() == before, "a crowd mech dies, another takes its place")
	var drawn: MechState = GameState.field.filter(func(m: MechState) -> bool: return field.mech_view(m.id) != null).front()
	var next: MechState = GameState.field.filter(func(m: MechState) -> bool: return crowd.has(m.id)).front()
	var spot := crowd.spot(next.id)
	drawn.wear = drawn.lifetime
	GameState.advance(GameState.TICK)
	await t.frames(2)
	var promoted := field.mech_view(next.id)
	t.check(promoted != null and not crowd.has(next.id) and promoted.position.distance_to(spot) < 6.0, "a drawn mech dies: the first in the crowd steps forward from its spot")
	GameState.credits = 1e9
	GameState.scrap = 1e9
	for i in 3:
		GameState.buy_upgrade("lines")
	for li in GameState.lines.size():
		for si in GameState.lines[li].segments.size():
			if li != 3:
				GameState.build_segment(li, si)
	GameState.lines[1].paused = true
	GameState.lines[2].segments[1].stall = SegmentState.Stall.NO_SCRAP
	t.check(range(4).map(func(i: int) -> Gates.Lamp: return Gates.lamp(GameState.lines[i])) == [Gates.Lamp.ON, Gates.Lamp.PAUSED, Gates.Lamp.STARVED, Gates.Lamp.OFF],
			"gate lamps: producing, paused, out of scrap, line not complete")
	await t.frames(2)
	var tags := range(4).map(func(i: int) -> Label: return main.line_view(i).get_node("Tag"))
	t.check(tags.all(func(l: Label) -> bool: return l.is_visible_in_tree()) and range(4).all(func(i: int) -> bool:
			return tags[i].text == str(i + 1) and (tags[i].get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Pal.line(i)),
			"each line's crew bar shows its number in its gate colour")
	var crew0: Label = main.line_view(0).get_node("Crew")
	t.check(crew0.position.x >= tags[0].position.x + tags[0].size.x, "crew count right of the tag")
	(main.get_node("%Scroll") as ScrollContainer).scroll_vertical = int(main.line_view(0).position.y)
	await t.frames(3)
	await t.shot("field_lines")
	(main.get_node("%Scroll") as ScrollContainer).scroll_vertical = 0
	var elite := MechState.new()
	elite.id = GameState.next_mech_id
	GameState.next_mech_id += 1
	elite.line = 2
	elite.parts = {"frame": 4, "core": 4, "arms": 4}
	GameState.call("_deploy", elite)
	await t.frames(2)
	var gates: Gates = field.get("_gates")
	t.check(float(gates.get("_open").get(2, 0.0)) > 0.0, "deploy opens its line's door")
	var elite_view := field.mech_view(elite.id)
	t.check(elite_view != null and elite_view.position.distance_to(Gates.door(2)) < 24.0, "the mech walks out of its line's door")
	var field_before := GameState.field.duplicate()
	GameState.field.clear()
	for pair: Array in [[0, 3.0], [2, 1.0]]:
		var m := MechState.new()
		m.line = pair[0]
		m.dps = pair[1]
		GameState.field.append(m)
	GameState.tap_dps = 0.0
	await t.frames(1)
	var strip := field.strip()
	t.check(strip.visible and strip.widths.size() == 5 and strip.widths[0] == 248 and strip.widths[2] == 82 and strip.widths[1] + strip.widths[3] + strip.widths[4] == 0,
			"DPS strip: one segment per line by its mechs' damage (%s)" % [strip.widths])
	t.check(strip.colors[2] == Pal.line(2) and strip.colors[4] == Pal.WHITE, "segments in the gate colours, taps white")
	GameState.tap_dps = 4.0
	await t.frames(1)
	t.check(strip.widths[4] == 165, "taps take their share (%s)" % [strip.widths])
	GameState.field.clear()
	GameState.tap_dps = 0.0
	await t.frames(1)
	t.check(not strip.visible, "no damage: no strip")
	GameState.field.assign(field_before)
	GameState.time_scale = 1.0
	var fired := field.shells
	await t.wait(3.0)
	t.check(field.shells - fired >= 3, "HIGH: artillery shells for the undrawn mechs (%d in 3 s)" % (field.shells - fired))
	await t.shot("field_artillery")
	Effects.level = Effects.LOW
	await t.frames(2)
	fired = field.shells
	await t.wait(2.0)
	t.check(field.shells == fired, "LOW: no artillery")
	Effects.level = Effects.HIGH
	GameState.time_scale = 1.0
	await t.wait(1.0)
	await t.shot("field_crowd")

	var offsets := range(30).map(func(w: int) -> float: return Battlefield.front_offset(w))
	t.check(offsets[0] == 0.0 and offsets[26] < Battlefield.FRONT_END and offsets[27] == Battlefield.FRONT_END, "front reaches the fortress at wave 28")
	t.check(range(1, 27).all(func(w: int) -> bool: return offsets[w] - offsets[w - 1] > offsets[w - 1] - (offsets[w - 2] if w > 1 else 0.0) - 0.01),
			"late waves advance further than early ones")
	await t.wait(3.0)
	GameState.time_scale = 0.0
	GameState.kill_wave()
	await t.frames(2)
	var walking := GameState.field.filter(func(m: MechState) -> bool: return field.mech_view(m.id) != null and field.mech_view(m.id).walking).size()
	t.check(field.advancing() and walking == field.mech_count(), "wave cleared: the front advances, every drawn mech walks (%d/%d)" % [walking, field.mech_count()])
	await t.wait(1.5)
	var ground: Sprite2D = field.get("_layers")[3]
	t.check(not field.advancing() and ground.region_rect.position.x == roundf(Battlefield.front_offset(GameState.wave)), "front stops at the next wave's spot")
	GameState.time_scale = 1.0
	t.check(Battlefield.is_boss_wave(4) and Battlefield.is_boss_wave(9) and not Battlefield.is_boss_wave(10), "boss on every 5th wave")
	GameState.time_scale = 0.0
	GameState.wave = 9
	GameState.wave_hp = GameState.wave_max_hp()
	await t.frames(2)
	var enemies: Array = field.get("_enemies")
	var bosses := enemies.filter(func(e: Sprite2D) -> bool: return e.get_meta("boss"))
	t.check(bosses.size() == 1 and bosses[0] == enemies[-1] and bosses[0].texture.resource_path.contains("enemy_boss_"),
			"boss wave: the heaviest enemy is the boss")
	t.check((field.get_node("HpLabel") as Label).text == "WAVE 10 BOSS", "wave bar says BOSS")
	GameState.time_scale = 1.0
	await t.wait(2.5)
	await t.shot("field_boss")
	for wave: int in [0, 9, 17, 23, 27]:
		GameState.wave = wave
		GameState.wave_hp = GameState.wave_max_hp()
		await t.wait(0.1)
		field.set("_front", -1.0)
		field.call("_update_front", 0.0)
		await t.wait(1.5)
		await t.shot("field_front_%d" % (wave + 1))

	if settings_backup:
		FileAccess.open(Save.SETTINGS_PATH, FileAccess.WRITE).store_string(settings_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.SETTINGS_PATH))


func _perf_fill(rng: RandomNumberGenerator) -> void:
	while GameState.field.size() < PERF_MECHS:
		var m := MechState.new()
		m.id = GameState.next_mech_id
		GameState.next_mech_id += 1
		m.parts = {"frame": rng.randi_range(0, 4), "core": rng.randi_range(0, 4), "arms": rng.randi_range(0, 4)}
		if rng.randf() < 0.6:
			m.parts["plating"] = rng.randi_range(0, 4)
		GameState.call("_deploy", m)
		m.wear = m.lifetime * rng.randf_range(0.0, 0.95)


func _perf_measure(rng: RandomNumberGenerator, frames: int) -> Dictionary:
	var frame_ms: Array[float] = []
	var nodes := 0
	var sleep := OS.low_processor_usage_mode_sleep_usec
	OS.low_processor_usage_mode_sleep_usec = 0
	var last := Time.get_ticks_usec()
	for k in frames:
		_perf_fill(rng)
		await t.frames(1)
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
		nodes = maxi(nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	OS.low_processor_usage_mode_sleep_usec = sleep
	var total := 0.0
	for ms in frame_ms:
		total += ms
	frame_ms.sort()
	return {"mean_ms": total / frames, "p95_ms": frame_ms[int(frames * 0.95)], "nodes": nodes}


func intro() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var line: LineView = main.line_view(0)
	var guide: IntroGuide = main.get_node("IntroGuide")
	var pile: Control = main.find_child("Pile", true, false)
	var arrow_x := func() -> float: return guide.get("_tip").x + guide.global_position.x
	t.check(guide.text() == "TAP THE SCRAP PILE", "fresh game: guide points at the pile (%s)" % guide.text())
	t.check(absf(arrow_x.call() - pile.get_global_rect().get_center().x) < 1.0, "arrow above the pile")
	var label: Label = guide.get_node("Text")
	var on_screen := func() -> bool: return main.get_global_rect().grow(-IntroGuide.MARGIN).encloses(label.get_global_rect())
	t.check(absf(label.get_global_rect().get_center().x - arrow_x.call()) <= 1.0 and on_screen.call(), "label centered on its arrow")
	await t.shot("intro_pile")
	for i in 10:
		await t.click(pile)
	t.check(guide.text() == "BUILD THE FRAME STATION" and on_screen.call(), "10 scrap: build the frame, label kept on screen (%s)" % guide.text())
	await t.shot("intro_build")
	await t.click(_build_button(line, 0))
	t.check(guide.text() == "TAP THE SCRAP PILE", "short on scrap again: back to the pile")
	for i in 40:
		await t.click(pile)
	for i in 2:
		await t.click(_build_button(line, i + 1))
	t.check(guide.text() == "TAP STATIONS TO BUILD A MECH", "all built: tap the stations (%s)" % guide.text())
	t.check(absf(arrow_x.call() - line.segment_view(0).get_global_rect().get_center().x) < 1.0, "arrow under the frame station")
	await t.shot("intro_stations")
	await _fill_bar(line, 0)
	t.check(absf(arrow_x.call() - line.segment_view(1).get_global_rect().get_center().x) < 1.0, "frame full: arrow moves to core")
	GameState.advance(0.1)
	await t.frames(1)
	t.check(GameState.lines[0].segments[0].assembling and absf(arrow_x.call() - line.segment_view(1).get_global_rect().get_center().x) < 1.0, "frame assembling (bar emptied): arrow stays on core")
	await _fill_bar(line, 1)
	t.check(absf(arrow_x.call() - line.segment_view(2).get_global_rect().get_center().x) < 1.0, "core full: arrow on arms")
	await _fill_bar(line, 2)
	await t.frames(1)
	t.check(guide.visible and not guide.get("_arrow"), "all bars full: text stays, no arrow")
	GameState.advance(4.0)
	await t.frames(2)
	t.check(guide.text() == "OUT OF SCRAP: TAP THE PILE", "stalled on scrap: back to the pile (%s)" % guide.text())
	for i in 10:
		await t.click(pile)
	GameState.advance(4.0)
	await t.frames(2)
	var field: Control = main.get_node("%Battlefield")
	t.check(GameState.mechs_built == 1 and guide.text() == "TAP THE FIELD TO HIT THE WAVE", "first mech deployed: tap the battlefield (%s)" % guide.text())
	var anchor: Control = field.hint_anchor()
	t.check(absf(arrow_x.call() - anchor.get_global_rect().get_center().x) < 1.0 and guide.get("_down"), "arrow points down at the enemies")
	await t.shot("intro_field")
	var field_tap: Control = field.find_child("FieldTap", true, false)
	for i in IntroGuide.FIELD_TAPS:
		await t.click(field_tap)
	await t.frames(1)
	t.check(not guide.visible, "%d battlefield taps: hint gone" % IntroGuide.FIELD_TAPS)
	var upgrades: Button = main.get_node("%Upgrades")
	GameState.credits = 1000.0
	await t.frames(2)
	t.check(guide.text() == "UPGRADE AVAILABLE" and absf(arrow_x.call() - upgrades.get_global_rect().get_center().x) < 1.0, "affordable upgrade: arrow on UPGRADES (%s)" % guide.text())
	await t.shot("intro_upgrade")
	await t.click(upgrades)
	await t.frames(2)
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	t.check(guide.text() == "BUY IT" and absf(arrow_x.call() - menu.first_affordable().get_global_rect().get_center().x) < 1.0, "menu open: arrow on the cheapest affordable row")
	var covered := (menu.find_children("*", "Label", true, false) + menu.find_children("Buy", "Button", true, false)).filter(func(c: Control) -> bool:
		return c.is_visible_in_tree() and c.get_global_rect().intersects(label.get_global_rect()))
	t.check(covered.is_empty() and label.get_global_rect().end.x < arrow_x.call() and on_screen.call(),
			"BUY IT beside its arrow, on no row text or buy button %s" % [covered.map(func(c: Control) -> String: return str(c.name))])
	await t.shot("intro_buy")
	await t.click(menu.first_affordable())
	await t.frames(2)
	t.check(not guide.visible, "first upgrade bought: guide gone for good")
	GameState.field_taps = 0
	GameState.field.clear()
	await t.frames(1)
	t.check(not guide.visible, "no field hint while the field is empty")


func audio() -> void:
	var settings_backup := FileAccess.get_file_as_string(Save.SETTINGS_PATH) if FileAccess.file_exists(Save.SETTINGS_PATH) else ""
	await _fresh()
	for id: String in Sound._beds:
		Sound._beds[id].gain = 0.0
	Sound.stop_music()
	await t.wait(Sound.MUSIC_STOP_FADE + 0.1)
	var main := t.get_tree().current_scene
	var cfg: Dictionary = Data.audio
	var missing := []
	for id: String in cfg.sounds:
		for s: AudioStream in Sound._sounds[StringName(id)].streams:
			if s == null or s.get_length() <= 0.0:
				missing.append(id)
	t.check(missing.is_empty(), "every sound file loads (%s)" % [missing])
	var buses := {}
	for id: String in cfg.sounds:
		buses[cfg.sounds[id].get("bus", "")] = true
	t.check(buses.keys().all(func(b: String) -> bool: return b in ["ui", "battle", "factory", "music"]) and buses.size() == 4, "every sound on the ui, battle, factory or music bus (%s)" % [buses.keys()])
	var loops := []
	for id: String in Sound._beds:
		var s: AudioStreamWAV = Sound._beds[id].player.stream
		if s.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			loops.append(id)
	t.check(loops.is_empty(), "beds import as forward loops (%s)" % [loops])
	t.check(absf(Sound._music.stream.get_length() - 44.65) < 0.1, "Ending loads (%.1f s)" % Sound._music.stream.get_length())

	var used := {}
	for dir: String in ["res://scenes", "res://ui", "res://autoload"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			for line in FileAccess.get_file_as_string(dir.path_join(f)).split("\n"):
				if "Sound.play" in line or "SHOT_SOUNDS" in line:
					var parts := line.split("&\"")
					for k in range(1, parts.size()):
						used[parts[k].get_slice("\"", 0)] = true
	for type_id: String in Data.line_slots():
		used["assemble_" + type_id] = true
	for e: Dictionary in Data.enemies.types:
		used["enemy_shot_" + e.sprite] = true
	var unknown := used.keys().filter(func(id: String) -> bool: return not cfg.sounds.has(id) and id != "silent")
	var unused: Array = cfg.sounds.keys().filter(func(id: String) -> bool: return not used.has(id))
	if OS.has_feature("editor"):
		t.check(unknown.is_empty() and unused.is_empty(), "code and audio.json use the same ids (unknown %s, unused %s)" % [unknown, unused])

	var pile: Control = main.find_child("Pile", true, false)
	var before := Sound.plays.duplicate()
	var played := func(id: StringName) -> int: return int(Sound.plays.get(id, 0)) - int(before.get(id, 0))
	for i in 3:
		await t.click(pile)
		await t.wait(0.15)
	t.check(played.call(&"pile_tap") == 3, "pile taps sound (%d, scrap %d)" % [played.call(&"pile_tap"), GameState.scrap])
	GameState.scrap = 1000.0
	await t.frames(2)
	var line: LineView = main.line_view(0)
	await t.click(_build_button(line, 0))
	t.check(played.call(&"build") == 1 and played.call(&"click") == 0, "build plays its own sound, no click")
	await t.frames(2)
	await t.click(line.segment_view(0).get_node("Tap"))
	t.check(played.call(&"station_tap") == 1, "station tap sounds")
	var soft := {"soften_db": 0.0, "soften_t": 0.0}
	var first := Sound._soften(soft, 100.0)
	var fast := 0.0
	for i in 10:
		fast = Sound._soften(soft, 100.1 + i * 0.1)
	var after := Sound._soften(soft, 103.0)
	var calm := 0.0
	for i in 6:
		calm = minf(calm, Sound._soften(soft, 110.0 + i / 3.0))
	t.check(first == 0.0 and fast <= float(cfg.soften.min_db) + 1.0 and after == 0.0 and calm == 0.0,
			"fast taps soften (%.1f dB at 10/s), full after a pause and at 3/s" % fast)
	var upgrades: Button = main.get_node("%Upgrades")
	t.check(not Sound.music_playing, "no music before the first mech")
	_reveal_all()
	await t.frames(2)
	t.check(Sound.music_playing and played.call(&"music") == 1, "music starts with the first mech")
	await t.click(upgrades)
	await t.click(upgrades)
	t.check(played.call(&"menu_open") == 1 and played.call(&"menu_close") == 1, "menu open/close sound")

	var hud: Hud = main.get_node("%Hud")
	var mute: Button = hud.get_node("MuteButton")
	var gear: Button = hud.get_node("SettingsButton")
	t.check(mute.get_global_rect().end.x <= gear.get_global_rect().position.x and mute.size.x >= 40.0, "mute button left of the gear")
	var was_muted := Sound.muted
	await t.click(mute)
	t.check(Sound.muted != was_muted and AudioServer.is_bus_mute(0) == Sound.muted, "mute toggle mutes Master")
	await t.frames(1)
	t.check(mute.icon == (Hud.SOUND_OFF if Sound.muted else Hud.SOUND_ON), "mute icon follows")
	await t.click(mute)
	t.check(Sound.muted == was_muted, "mute toggles back")
	GameState.credits = 99900.0
	GameState.credits_rate = 99900.0
	await t.frames(2)
	await t.shot("audio_hud")
	await t.click(gear)
	var settings: SettingsOverlay = main.get_node("%Settings")
	t.check(not settings.find_child("Volume_music", true, false).is_visible_in_tree(), "volume rows not on the settings page")
	await t.click(settings.find_child("AudioButton", true, false))
	var rows: Array = Sound.BUSES.keys().map(func(key: String) -> Control: return settings.find_child("Volume_" + key, true, false))
	t.check(rows.all(func(r: Control) -> bool: return r.is_visible_in_tree() and settings.get_global_rect().encloses(r.get_global_rect())),
			"AUDIO: a row per bus (%d), on screen" % rows.size())
	await t.shot("audio_settings")
	var off := []
	for key: String in Sound.BUSES:
		var level := linear_to_db(pow(float(Sound.steps[key]) / float(cfg.steps), 2.0)) + float(cfg.trim_db[key]) + (Sound._duck if key == "ambience" else 0.0)
		if absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sound.BUSES[key])) - level) > 0.01:
			off.append(key)
	t.check(off.is_empty(), "buses at their step level + trim_db (%s)" % [off])
	var music_step := int(Sound.steps.music)
	await t.click(settings.find_child("Volume_music", true, false).get_node("Down"))
	t.check(int(Sound.steps.music) == music_step - 1, "settings MUSIC - lowers the step")
	Sound.set_step("music", 0)
	t.check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "step 0 mutes the bus")
	Sound.set_step("music", music_step)
	Sound.set_step("master", 0)
	t.check(AudioServer.is_bus_mute(0), "MASTER 0 mutes everything")
	Sound.set_step("master", int(cfg.defaults.master))
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.SETTINGS_PATH))
	t.check(int(saved.music) == music_step and bool(saved.muted) == was_muted, "settings saved to %s" % Save.SETTINGS_PATH)
	await t.click(settings.find_child("Close", true, false))
	t.check(settings.visible and settings.find_child("AudioButton", true, false).is_visible_in_tree(), "BACK returns to settings")
	await t.click(settings.find_child("Close", true, false))

	var field: Battlefield = main.get_node("%Battlefield")
	t.check(is_equal_approx(Sound.visible_share(field), 1.0), "battlefield fully present")
	Sound.presence.field = 0.0
	t.check(is_equal_approx(Sound._area_gain("field"), db_to_linear(cfg.areas.field.hidden_db)), "hidden area plays at hidden_db")
	await t.frames(1)
	t.check(Sound.presence.field == 1.0, "main keeps presence up to date")
	t.check(Sound._beds.battle.gain < 0.05, "battle bed silent with no mechs (%.2f)" % Sound._beds.battle.gain)

	GameState.time_scale = 10.0
	GameState.scrap = 1e9
	GameState.credits = 1e9
	for i in 2:
		GameState.buy_upgrade("lines")
	for li in GameState.lines.size():
		for si in GameState.lines[li].segments.size():
			GameState.build_segment(li, si)
		for k in 6:
			GameState.hire_worker(li)
	_spawn_mechs(50)
	var field_ids: Array = cfg.sounds.keys().filter(func(id: String) -> bool: return cfg.sounds[id].get("group", "") == "field")
	var field_count := func() -> int:
		var n := 0
		for id: String in field_ids:
			n += int(Sound.plays.get(StringName(id), 0))
		return n
	var worst := 0
	var over_voices := []
	for sec in 8:
		var start: int = field_count.call()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1000:
			await t.frames(1)
			var now := Sound._now()
			for id: StringName in Sound._sounds:
				if Sound._voices(id, now) > int(Sound._sounds[id].cfg.get("voices", Sound.POOL)):
					over_voices.append(id)
		worst = maxi(worst, field_count.call() - start)
	t.check(worst > 0 and worst <= int(cfg.groups.field), "busy battlefield: %d field sounds/s (budget %d)" % [worst, cfg.groups.field])
	t.check(over_voices.is_empty(), "voice caps hold (%s)" % [over_voices])
	t.check(Sound._beds.battle.gain > 0.5, "battle bed up with a full field (%.2f, %d drawn)" % [Sound._beds.battle.gain, field.mech_count()])
	t.check(Sound._beds.factory.gain > 0.5, "factory bed up while lines assemble (%.2f, %.1f/s)" % [Sound._beds.factory.gain, Sound.drives.assembly_rate])
	t.check(played.call(&"coin") > 0 and played.call(&"shot_pipe") > 0 and played.call(&"enemy_pop") > 0, "coins, shots and pops sound")
	GameState.kill_wave()
	await t.wait(0.5)
	t.check(played.call(&"wave_clear") >= 1 and played.call(&"bounty") >= 1, "wave clear + bounty")

	GameState.time_scale = 1.0
	for li in GameState.lines.size():
		if not GameState.lines[li].paused:
			GameState.toggle_pause(li)
	await t.wait(12.0)
	t.check(Sound._beds.factory.gain < 0.08, "factory bed fades with all lines paused (%.2f)" % Sound._beds.factory.gain)

	var music: Dictionary = cfg.music
	var length: float = Sound._music.stream.get_length()
	var left := Sound._music_end - Sound._now()
	t.check(Sound._music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and left > length * (int(music.loops) - 1) and left < length * int(music.loops),
			"music loops %d× per play (%.0f s left)" % [music.loops, left])
	var amb := AudioServer.get_bus_index(&"Ambience")
	var amb_db := linear_to_db(pow(float(Sound.steps.ambience) / float(cfg.steps), 2.0)) + float(cfg.trim_db.ambience)
	t.check(absf(AudioServer.get_bus_volume_db(amb) - amb_db - float(music.duck_db)) < 0.5, "ambience ducks while music plays")
	t.check(absf(Sound._music.volume_db - float(music.volume_db)) < 0.5, "music faded in to %.0f dB" % Sound._music.volume_db)
	Sound._music_end = Sound._now() + float(music.fade_out)
	await t.wait(float(music.fade_out) + 0.3)
	t.check(not Sound.music_playing and Sound._music_wait >= float(music.gap[0]) - 1.0 and Sound._music_wait <= float(music.gap[1]),
			"music fades out at the end, next in %.0f s" % Sound._music_wait)
	GameState.run_over = true
	Sound._music_wait = 0.01
	await t.wait(0.1)
	t.check(not Sound.music_playing, "no scheduled music once the run is over")
	GameState.run_over = false

	var battle_step := int(Sound.steps.battle)
	Sound.set_muted(true)
	Sound.steps.battle = battle_step % int(cfg.steps) + 1
	Sound._load_settings()
	t.check(Sound.muted and int(Sound.steps.battle) == battle_step, "settings reload from the file")
	Save.reset_run()
	await t.frames(3)
	t.check(Sound.muted, "reset run keeps sound settings")
	Sound.play_music()
	Save.reset_run()
	await t.wait(Sound.MUSIC_STOP_FADE + 0.3)
	t.check(not Sound.music_playing, "start again stops the music")
	_reveal_all()
	await t.frames(2)
	t.check(Sound.music_playing, "the new run's first mech starts it again")
	if settings_backup:
		FileAccess.open(Save.SETTINGS_PATH, FileAccess.WRITE).store_string(settings_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.SETTINGS_PATH))
	Sound._load_settings()


func _reveal_all() -> void:
	GameState.mechs_built = maxi(GameState.mechs_built, 1)
	for key: String in GameState.REVEALS:
		GameState.seen[key] = true


func _fresh(frozen := true) -> void:
	GameState.time_scale = 0.0 if frozen else 1.0
	GameState.new_game()
	t.get_tree().reload_current_scene()
	await t.frames(3)


func _centered(line: LineView, n: int) -> bool:
	var left: float = line.segment_view(0).position.x - line.call("_left")
	var right := line.size.x - line.segment_view(n - 1).position.x - SegmentView.WIDTH
	return absf(left - right) < 1.0 and left >= 0.0


func _build_button(line: LineView, i: int) -> Button:
	return line.segment_view(i).get_node("Build")


func _buy(menu: UpgradeMenu, id: String) -> Button:
	return menu.find_child("Row_" + id, true, false).find_child("Buy", true, false)


func _spawn_mechs(n: int) -> void:
	GameState.debug_spawn_mechs(n)


func _sorted(menu: UpgradeMenu) -> bool:
	var keys := []
	for id: String in Data.upgrade_list.map(func(r: Dictionary) -> String: return r.id):
		keys.append([menu.row(id).get_index(), 1 if GameState.upgrade_maxed(id) else 0, GameState.upgrade_cost(id)])
	keys.sort()
	for i in range(1, keys.size()):
		if keys[i][1] < keys[i - 1][1] or (keys[i][1] == keys[i - 1][1] and keys[i][2] < keys[i - 1][2]):
			return false
	return true


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




