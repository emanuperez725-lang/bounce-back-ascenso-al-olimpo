extends SceneTree
## Headless smoke test:
## godot --headless --path . -s res://tests/test_player.gd

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var p: Player = main.get_node("Player")
	p.hitstop_time = 0.0 # keep the test independent of Engine.time_scale

	await _frames(30)
	_check(p.is_on_floor(), "lands on floor")

	var tap := await _jump_apex(p, 3)
	var full := await _jump_apex(p, 30)
	_check(full > tap + 10.0, "variable jump height (tap %.1f < full %.1f)" % [tap, full])

	# Air dash uses the charge, ground refills it.
	p.global_position = Vector2(60, 100) # open air, clear path to the right
	p.velocity = Vector2.ZERO
	Input.action_press("dash")
	await _frames(2) # script-pressed actions register as "just pressed" one frame later
	var x0 := p.global_position.x
	Input.action_release("dash")
	_check(p.dashes == 0, "air dash consumes charge")
	await _frames(8)
	_check(p.global_position.x - x0 > 25.0, "dash moves forward (%.1f px)" % (p.global_position.x - x0))
	await _frames(120) # land, or fall off screen and respawn: either refills
	_check(p.dashes == 1, "landing refills dash")

	print("FAIL" if _failed else "ALL TESTS PASSED")
	quit(1 if _failed else 0)


func _jump_apex(p: Player, hold_frames: int) -> float:
	await _frames(40)
	var y0 := p.global_position.y
	var apex := y0
	Input.action_press("jump")
	for i in 60:
		if i == hold_frames:
			Input.action_release("jump")
		await physics_frame
		apex = minf(apex, p.global_position.y)
	Input.action_release("jump")
	return y0 - apex


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		_failed = true
