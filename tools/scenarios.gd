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
	t.check(t.node("Scrapyard").get_parent().name == "BottomBar" and content.find_child("Scrapyard", true, false) == null, "scrapyard sits in the fixed bottom bar, not in the pane")
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

	_spawn_mechs(3)
	await t.frames(1)
	var label: Label = field.get_node("DpsLabel")
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
	GameState.mechs_built = 1
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
	var assembled := GameState.lines[0].segments[0].assemblies
	await t.click(line.get_node("Pause"))
	GameState.advance(3.0)
	t.check(GameState.lines[0].segments[0].assemblies > assembled and not GameState.lines[0].paused, "unpaused: production resumes")

	var before := JSON.stringify(GameState.to_dict(), "", true)
	Save.save_game()
	GameState.new_game()
	Save.load_game()
	t.check(before == JSON.stringify(GameState.to_dict(), "", true), "reload keeps workers and pause")


func m4() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var menu: UpgradeMenu = main.get_node("%UpgradeMenu")
	GameState.mechs_built = 1
	await t.frames(1)
	await t.click(main.get_node("%Upgrades"))
	t.check(menu.visible, "UPGRADES opens the menu")
	await t.frames(1)
	var buy := _buy(menu, "tap")
	t.check(buy.disabled and menu.row("tap").modulate != Color.WHITE, "unaffordable rows are grey")
	await t.shot("m4_menu")

	GameState.credits = 1e6
	var checks := [
		["bar", "bar_mult", 0.9],
		["crew", "worker_slots", 4.0],
		["tap", "scrap_per_tap", 2.0],
		["raises", "payout_cap", 1.0],
		["salvage", "salvage", 0.05],
		["lines", "lines", 2.0],
	]
	for c: Array in checks:
		await t.click(_buy(menu, c[0]))
		t.check(is_equal_approx(GameState.stat(c[1]), c[2]), "%s is now %s" % [c[1], GameState.stat(c[1])])
	t.check(GameState.lines.size() == 2 and main.line_view(1) != null, "line 2 unlocked and shown")
	t.check(is_equal_approx(GameState.upgrade_cost("tap"), 25.0 * Data.econ("upgrade_cost_growth")), "cost base·growth^level")
	t.check(is_equal_approx(GameState.lines[0].segments[0].bar_size(), 5.4), "sim reads the derived bar size")

	for i in 20:
		await t.click(_buy(menu, "salvage"))
	t.check(GameState.upgrade_maxed("salvage") and is_equal_approx(GameState.salvage_share(), 0.4), "salvage stops at 40%")
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
	t.check(line.get_node("Pause").position.x < 20, "pause sits at the left of the line")
	t.check(_centered(line, 3), "3 segments centered right of the pause strip (x %d)" % line.segment_view(0).position.x)
	var pause_rect: Rect2 = line.get_node("Pause").get_rect()
	t.check(is_zero_approx(pause_rect.position.y) and pause_rect.end.y >= SegmentView.BELT_Y and pause_rect.end.x <= line.segment_view(0).position.x, "pause strip spans names to belt, left of the stations")

	GameState.mechs_built = 1
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
	for i in 3:
		await t.click(line.segment_view(0).get_node("Hire"))
	await t.frames(1)
	var full_hire: Button = line.segment_view(0).get_node("Hire")
	var free_hire: Button = line.segment_view(1).get_node("Hire")
	t.check(full_hire.visible and full_hire.disabled and full_hire.text == "MAX" and not free_hire.disabled, "full station: hire stays, reads MAX, disabled")
	t.check(full_hire.get_rect() == free_hire.get_rect(), "hire buttons keep their size")

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
	t.check(apply0.visible and apply0.disabled, "no tier to apply yet: arrow shown, disabled")
	await t.click(main.get_node("%Upgrades"))
	GameState.credits = 300.0
	await t.click(_buy(menu, "tier_frame"))
	t.check(GameState.unlocked_tier("frame") == 1, "Bolted Frame unlocked for 300 credits")
	await t.shot("m5_unlocked")
	await t.click(main.get_node("%Upgrades"))

	await t.click(line.get_node("Pause"))
	GameState.scrap = 0.0
	GameState.advance(10.0)
	t.check(GameState.lines[0].paused and is_zero_approx(GameState.scrap), "paused line saves scrap")
	GameState.scrap = 60.0
	await t.frames(1)
	await t.click(line.segment_view(0).get_node("Apply"))
	t.check(segs[0].tier == 1 and is_zero_approx(GameState.scrap), "apply Bolted Frame for 60 scrap")
	await t.click(line.get_node("Pause"))
	GameState.scrap = 1000.0
	GameState.field.clear()
	for k in 3:
		for i in 3:
			await _fill_bar(line, i)
		GameState.advance(3.0)
	var m: MechState = GameState.field[-1]
	t.check(m.parts.frame == 1 and is_equal_approx(m.lifetime, 26.0), "new mechs have Bolted Frames and live 26 s")
	t.check(is_equal_approx(m.scrap_cost, 6.0 + 3.0 + 3.0), "scrap per mech rises to 12")
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
	await t.frames(30)
	await t.shot("m5_plating")

	GameState.wave = 10
	var aged := MechState.new()
	aged.lifetime = 20.0
	GameState.field = [aged]
	GameState.advance(20.0 / 1.5 + 0.1)
	t.check(GameState.field.is_empty(), "wave 11: mechs age 1.5x and die after 13.3 s")


func m6() -> void:
	await _fresh()
	var main := t.get_tree().current_scene
	var field: Battlefield = main.get_node("%Battlefield")
	GameState.time_scale = 1.0
	GameState.debug_spawn_mechs(3)
	await t.frames(2)
	var view := field.mech_view(GameState.field[0].id)
	t.check(view.walking, "mechs walk in")
	await t.wait(6.0)
	t.check(not view.walking, "and hold a slot")
	var bullets := field.find_children("*", "Sprite2D", true, false).filter(func(n: Node) -> bool:
		return n.texture == preload("res://art/fx/bullet.png") or n.texture == preload("res://art/fx/enemy_bullet.png"))
	await t.shot("m6_fight")
	var fired := 0
	for k in 60:
		await t.frames(1)
		fired = maxi(fired, field.find_children("*", "Sprite2D", true, false).filter(func(n: Node) -> bool:
			return n.texture == preload("res://art/fx/bullet.png")).size())
	t.check(fired > 0 or bullets.size() > 0, "mechs fire at the wave")
	var drone: Sprite2D = field.find_children("*", "Sprite2D", true, false).filter(func(n: Sprite2D) -> bool:
		return n.texture and n.texture.resource_path.contains("enemy_")).front()
	var drawn := drone.get_rect()
	drawn.position += drone.position
	t.check(drawn.has_point(field.call("_enemy_center", drone)) and absf(field.call("_enemy_center", drone).y - drawn.get_center().y) < 1.0, "bullets aim at the enemy's drawn center")

	var m: MechState = GameState.field[0]
	for pair: Array in [[0.9, 0], [0.6, 1], [0.4, 2], [0.2, 3], [0.1, 4]]:
		m.wear = m.lifetime * (1.0 - pair[0])
		await t.frames(1)
		t.check(view.damage_stage() == pair[1], "remaining %d%%: damage stage %d" % [pair[0] * 100, pair[1]])
	await t.shot("m6_damaged")

	GameState.debug_spawn_mechs(50)
	await t.frames(2)
	t.check(field.mech_count() == 24 and GameState.field.size() == 53, "53 mechs simulated, 24 drawn")
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
		GameState.hire_worker(0, i)
	GameState.mechs_built = 1
	await t.frames(1)
	await t.click(main.get_node("%Upgrades"))
	for i in 4:
		await t.click(_buy(menu, "tier_arms"))
	t.check(GameState.unlocked_tier("arms") == 4, "Railgun unlocked")
	await t.click(_buy(menu, "final_arms"))
	t.check(menu.get_node("Confirm").visible and GameState.level("final_arms") == 0, "Atomic Missile asks to confirm")
	await t.shot("m7_confirm")
	await t.click(menu.find_child("Yes", true, false))
	t.check(GameState.unlocked_tier("arms") == 5, "Atomic Missile unlocked")
	await t.click(main.get_node("%Upgrades"))
	for i in 5:
		await t.click(line.segment_view(2).get_node("Apply"))
	t.check(GameState.lines[0].segments[2].tier == 5, "applied to the Arms segment")

	GameState.time_scale = 1.0
	var start := Time.get_ticks_msec()
	while not GameState.run_over and Time.get_ticks_msec() - start < 20000:
		for i in 3:
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
	t.check(hidden.all(func(c: Control) -> bool: return not c.visible), "fresh game: UPGRADES, UNLOCK LINE, YARD WORKER hidden")
	GameState.scrap = 45.0
	for i in 3:
		await t.click(_build_button(line, i))
	GameState.scrap = 100.0
	for k in 3:
		await _fill_bar(line, k)
	GameState.advance(3.0)
	await t.frames(1)
	t.check(GameState.mechs_built == 1 and hidden.all(func(c: Control) -> bool: return c.visible), "first mech deployed: the buttons appear")

	t.check(line.size.y < 200.0, "line takes %d px (M7: 238)" % line.size.y)
	t.check(line.segment_view(0).find_child("Jump", false, false) == null and line.segment_view(0).find_child("Bottleneck", false, false) == null, "no jump button, no bottleneck box")
	var hud: Hud = main.get_node("%Hud")
	t.check(hud.target(Flyers.Kind.SCRAP).x < hud.target(Flyers.Kind.CREDITS).x, "HUD: scrap left, credits right")

	GameState.field.clear()
	GameState.credits = 1e6
	for i in 3:
		for k in 3:
			GameState.hire_worker(0, i)
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
	m.age = 4.6
	t.check(is_equal_approx(GameState.payout_rate(m), 1.5), "faster raises: first raise at 4.5 s")
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
	GameState.mechs_built = 1
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
	var hire: Button = sv.get_node("Hire")
	var apply: Button = sv.get_node("Apply")
	t.check(hire.visible and apply.visible and absf(hire.position.y - apply.position.y) < 1.0, "hire and apply share one row")
	t.check(hire.get_rect().end.x <= apply.position.x and apply.get_rect().end.x <= 84.0, "they fit the segment (%s, %s)" % [hire.get_rect(), apply.get_rect()])
	await t.shot("m8_row")
	await t.click(apply)
	t.check(GameState.lines[0].segments[0].tier == 1, "apply from the shared row")

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
	GameState.wave_hp = GameState.wave_max_hp() * 0.4
	await t.frames(60)
	var enemies := field.find_children("Damage", "DamageFx", true, false).filter(func(d: DamageFx) -> bool:
		return (d.get_parent() as CanvasItem).visible)
	t.check(enemies.size() > 0 and enemies.all(func(d: DamageFx) -> bool: return d.stage >= 2), "wave at 40%%: %d enemies smoke" % enemies.size())
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
	t.check(is_equal_approx(expect, 0.05 * GameState.wave_max_hp() * first.weight / GameState.wave_enemies().reduce(func(a: float, e: Dictionary) -> float: return a + e.weight, 0.0)), "kill scrap is 5% of the enemy's HP")
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
	var usage: Label = line.find_child("Usage", true, false)
	GameState.advance(1.0)
	await t.frames(2)
	t.check(GameState.lines[0].scrap_used_rate > 0.0 and usage.text.replace("\n", "") == Fmt.whole(GameState.lines[0].scrap_used_rate), "line scrap usage shows %s/s" % usage.text.replace("\n", ""))
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
	var yard: Control = main.find_child("Yard", true, false)
	var bar_center: float = main.find_child("BottomBar", true, false).get_global_rect().get_center().x
	var pile_x := func() -> float: return yard.get_node("PileSprite").get_global_rect().get_center().x
	t.check(absf(pile_x.call() - bar_center) < 2.0, "scrapyard starts centered (%d vs %d)" % [pile_x.call(), bar_center])
	await t.shot("m8_yard_centered")
	GameState.credits = 100.0
	GameState.mechs_built = 1
	await t.wait(0.6)
	t.check(pile_x.call() < bar_center - 50.0, "it moves left when the buttons appear (%d)" % pile_x.call())
	var badge: Label = main.get_node("%Upgrades").get_node("Badge")
	t.check(badge.visible and badge.text == str(GameState.affordable_upgrades()) and GameState.affordable_upgrades() > 0, "UPGRADES shows %s affordable" % badge.text)
	t.check(main.get("_title") == "(%d) Scrap Titans" % GameState.affordable_upgrades(), "window title shows the count: %s" % main.get("_title"))
	await t.shot("m8_badge")
	GameState.credits = 0.0
	await t.frames(2)
	t.check(badge.visible and badge.text == "0", "badge stays, reads 0 when nothing is affordable")
	t.check(main.get("_title") == "Scrap Titans", "plain title when nothing is affordable")

	var hud_mechs: Label = main.find_child("Mechs", true, false)
	var hud_rate: Label = main.find_child("MechsRate", true, false)
	var built := GameState.mechs_built
	GameState.debug_spawn_mechs(3)
	GameState.advance(1.1)
	await t.frames(2)
	t.check(hud_mechs.text == str(built + 3) and GameState.mechs_per_min == 3 and hud_rate.text == "3/MIN", "HUD: %s mechs, %s" % [hud_mechs.text, hud_rate.text])
	GameState.advance(60.0)
	await t.frames(2)
	t.check(GameState.mechs_per_min == 0 and hud_rate.text == "0/MIN", "rate covers the last minute")

	GameState.wave = 3
	GameState.wave_hp = GameState.wave_max_hp()
	GameState.credits = 0.0
	await t.frames(30)
	var field_tap: Control = main.find_child("FieldTap", true, false)
	flyers = main.get_node("%Flyers")
	for c in flyers.get_children():
		c.free()
	await t.click(field_tap)
	t.check(is_equal_approx(GameState.wave_hp, GameState.wave_max_hp() * 0.99), "a battlefield tap deals 1% of the wave HP")
	t.check(is_equal_approx(GameState.credits, GameState.wave_bounty() * 0.01), "and pays 1%% of the bounty (%.2f)" % GameState.credits)
	var tap_at := field_tap.get_global_rect().get_center()
	t.check(flyers.get_child_count() == 2 and flyers.get_children().all(func(d: Control) -> bool: return (d.position + d.size / 2.0).distance_to(tap_at) < 30.0), "two credit discs burst from the tap point")
	GameState.credits = 1e6
	for i in 4:
		GameState.buy_upgrade("tap_damage")
	var hp := GameState.wave_hp
	await t.click(field_tap)
	t.check(is_equal_approx(hp - GameState.wave_hp, GameState.wave_max_hp() * 0.05), "Tap damage chain: 5% per tap")
	GameState.wave_hp = GameState.wave_max_hp() * 0.03
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

	var motion := InputEventMouseMotion.new()
	motion.position = pile.get_global_rect().get_center()
	motion.global_position = motion.position
	t.get_viewport().push_input(motion, true)
	await t.frames(2)
	t.check(pile.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "pile shows a hand cursor")
	t.check(not Hover.enabled() or yard.get_node("PileSprite").self_modulate == Hover.TINT, "hovering the pile lights it up")
	var gear: Button = main.find_child("SettingsButton", true, false)
	t.check(gear.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and main.get_node("%Upgrades").mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "buttons show a hand cursor")


func tune() -> void:
	t.get_tree().current_scene.free()
	GameState.time_scale = 0.0
	GameState.new_game()
	var step := 0.25
	var taps := 0.0
	var events := []
	var seen := {}
	while not GameState.run_over and GameState.run_time < 5400.0:
		taps += TAPS_PER_S * step
		while taps >= 1.0:
			taps -= 1.0
			_bot_tap()
		if fmod(GameState.run_time, 1.0) < step * 0.5:
			_bot_manage(events)
		GameState.advance(step)
		var minute := int(GameState.run_time / 60.0)
		if not seen.has(minute):
			seen[minute] = true
			print("  %3d min  cr %s (%s) earned %s  scrap %s (%s)  wave %d  dps %s  field %d  lines %d  tiers %s" % [
				minute, Fmt.num(GameState.credits), Fmt.rate(GameState.credits_rate), Fmt.num(GameState.credits_earned),
				Fmt.num(GameState.scrap), Fmt.rate(GameState.scrap_rate), GameState.wave + 1, Fmt.num(GameState.field_dps()),
				GameState.field.size(), GameState.lines.size(),
				Data.line_slots().map(func(k: String) -> int: return GameState.unlocked_tier(k) + 1)])
	for e: Array in events:
		print("  %5.1f min  %s" % [e[0] / 60.0, e[1]])
	var first_worker: float = events.filter(func(e: Array) -> bool: return e[1].begins_with("hire")).front()[0]
	t.check(first_worker < 240.0, "first worker at %.1f min" % (first_worker / 60.0))
	t.check(GameState.run_over and GameState.run_time > 1800.0 and GameState.run_time < 3600.0, "nuke at %.1f min" % (GameState.run_time / 60.0))
	GameState.new_game()


const TAPS_PER_S := 3.0


func _bot_tap() -> void:
	if GameState.scrap < 30.0:
		GameState.tap_pile()
		return
	var best := [-1, -1]
	var best_fill := 2.0
	for li in GameState.lines.size():
		var line := GameState.lines[li]
		if line.paused or not line.is_complete():
			continue
		for i in line.segments.size():
			var s := line.segments[i]
			if s.built and not s.bar_full() and s.work / s.bar_size() < best_fill:
				best_fill = s.work / s.bar_size()
				best = [li, i]
	if best[0] == -1:
		GameState.tap_pile()
	else:
		GameState.tap_segment(best[0], best[1])


func _bot_manage(events: Array) -> void:
	var now := GameState.run_time
	for li in GameState.lines.size():
		for i in GameState.lines[li].segments.size():
			if not GameState.lines[li].segments[i].built and GameState.build_segment(li, i):
				events.append([now, "build L%d %s" % [li + 1, GameState.lines[li].segments[i].type_id]])
	var pending := INF
	var nuke_ready: bool = GameState.unlocked_tier("arms") == Data.segment_type("arms").tiers.size() - 1
	for li in GameState.lines.size():
		for i in GameState.lines[li].segments.size():
			if GameState.can_apply_tier(li, i) and (not nuke_ready or (li == 0 and i == 2)):
				var cost := GameState.tier_apply_cost(li, i)
				var s := GameState.lines[li].segments[i]
				if GameState.apply_tier(li, i):
					events.append([now, "apply L%d %s" % [li + 1, s.tier_data().part]])
				else:
					pending = minf(pending, cost)
	var save := pending < INF and GameState.scrap_rate * 60.0 < pending - GameState.scrap
	if nuke_ready:
		save = GameState.lines[0].segments[2].tier < GameState.unlocked_tier("arms")
	for li in GameState.lines.size():
		if GameState.lines[li].paused != save:
			GameState.toggle_pause(li)
	while true:
		var options := []
		for li in GameState.lines.size():
			for i in GameState.lines[li].segments.size():
				var s := GameState.lines[li].segments[i]
				if s.built and s.workers < s.worker_slots():
					options.append([GameState.worker_cost(li, i), "hire", li, i])
		if GameState.yard_workers < GameState.yard_slots():
			options.append([GameState.yard_worker_cost(), "yard"])
		for r: Dictionary in Data.upgrade_list:
			if GameState.upgrade_visible(r.id) and not GameState.upgrade_maxed(r.id) and not GameState.upgrade_locked(r.id):
				options.append([GameState.upgrade_cost(r.id), "buy", r.id])
		options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		if options.is_empty() or options[0][0] > GameState.credits:
			return
		var o: Array = options[0]
		match o[1]:
			"hire":
				GameState.hire_worker(o[2], o[3])
				if not events.any(func(e: Array) -> bool: return e[1].begins_with("hire")):
					events.append([now, "hire first worker"])
			"yard":
				GameState.hire_yard_worker()
			"buy":
				GameState.buy_upgrade(o[2])
				var r := Data.upgrade_row(o[2])
				if r.get("kind", "") != "" or o[2] in ["lines", "kill_scrap"]:
					events.append([now, "%s %d" % [o[2], GameState.level(o[2])]])


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


func _centered(line: LineView, n: int) -> bool:
	var left := line.segment_view(0).position.x - LineView.PAUSE_W
	var right := 360.0 - line.segment_view(n - 1).position.x - SegmentView.WIDTH
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



