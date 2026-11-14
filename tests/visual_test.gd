extends SceneTree
## Visual smoke test: real rendering + real key events (not action_press).
## godot --path . -s res://tests/visual_test.gd   -> PNGs in tests/shots/

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(name: String, p: Player) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/%s.png" % name)
	print("%s pos=%s vel=%s dashes=%d" % [name, p.global_position, p.velocity, p.dashes])


func _check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	_failed = _failed or not ok


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(5)
	var p: Player = current_scene.get_node("Player")
	await _wait(30)
	await _shot("0_start", p)
	var start := p.global_position

	_key(KEY_C, true)
	await _wait(18)
	await _shot("1_jump", p)
	_check(start.y - p.global_position.y > 20.0, "C jumps (rise %.1f px)" % (start.y - p.global_position.y))
	_key(KEY_C, false)
	await _wait(40)

	_key(KEY_RIGHT, true)
	await _wait(40) # run up close to pit 1 (Celeste 1:1 speed, 90 px/s)
	await _shot("2_run_right", p)
	_check(p.global_position.x - start.x > 45.0, "right arrow runs (%.1f px)" % (p.global_position.x - start.x))

	_key(KEY_C, true)
	await _wait(8)
	_key(KEY_X, true)
	await _wait(5)
	await _shot("3_dash", p)
	_check(p.dashes == 0, "X dashes in the air")
	_key(KEY_X, false)
	_key(KEY_C, false)
	_key(KEY_RIGHT, false) # stop before pit 2
	await _wait(60)
	await _shot("4_end", p)
	_check(p.global_position.x > 148.0, "jump + dash crosses the first pit (x %.1f)" % p.global_position.x)

	print("FAIL" if _failed else "ALL VISUAL TESTS PASSED")
	quit(1 if _failed else 0)
