extends Node

var failures := 0
var shots_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--scenario")
	if i == -1:
		return
	var scenario := args[i + 1] if i + 1 < args.size() else ""
	var j := args.find("--shots")
	if j != -1 and j + 1 < args.size():
		shots_dir = args[j + 1]
		DirAccess.make_dir_recursive_absolute(shots_dir)
	await frames(2)
	var script: GDScript = load("res://tools/scenarios.gd")
	var runner: Object = script.new(self) if script and script.can_instantiate() else null
	if runner == null or not runner.has_method(scenario):
		printerr("Unknown scenario: ", scenario)
		Sound.shutdown()
		await wait(0.1)
		get_tree().quit(2)
		return
	print("SCENARIO ", scenario)
	await runner.call(scenario)
	print("RESULT %s: %s" % [scenario, "FAIL (%d)" % failures if failures else "PASS"])
	Sound.shutdown()
	await wait(0.1)
	get_tree().quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])


func frames(n: int = 1) -> void:
	for k in n:
		await get_tree().process_frame


func node(unique_name: String) -> Node:
	return get_tree().current_scene.get_node("%" + unique_name)


func click(target: Control) -> void:
	var scroll := target.get_parent()
	while scroll and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll:
		scroll.ensure_control_visible(target)
		await frames(1)
	var pos := target.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev, true)
	await frames(1)


func touch(target: Control, index: int, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = target.get_global_rect().get_center() + Vector2(index * 4, 0)
	get_viewport().push_input(ev, true)


func shot(shot_name: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := shots_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("  shot ", path)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
