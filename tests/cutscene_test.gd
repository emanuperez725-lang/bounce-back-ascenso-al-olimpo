extends SceneTree
## Intro and ending cutscenes: every card shows, skipping works, the last page leads on.
## godot --path . -s res://tests/cutscene_test.gd   -> tests/shots/intro_*.png, ending_*.png

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _scene("res://scenes/intro.tscn", "intro")
	_check(current_scene.name == "Game", "intro ends in the game")
	root.set_meta("stats", {"falls": 7, "parries": 3, "time": 125.0})
	await _scene("res://scenes/ending.tscn", "ending")
	_check(current_scene.name == "Intro", "ending goes back to the intro")
	print("FAIL" if _failed else "ALL CUTSCENES PASSED")
	quit(1 if _failed else 0)


## Play a cutscene: shot each card mid-way, skip it, then press on the last page.
func _scene(path: String, tag: String) -> void:
	change_scene_to_file(path)
	await process_frame
	await process_frame
	var cs: Cutscene = current_scene
	for i in cs.cards.size():
		await _seconds(1.6)
		await _shot("%s_%d" % [tag, i])
		_press()
	for i in 300: # up to 30 s
		if cs.done:
			break
		await _seconds(0.1)
	_check(cs.done, "%s reaches its last page" % tag)
	if tag == "ending":
		_check(cs.get_node("Stats").text.contains("Caídas: 7") and cs.get_node("Stats").text.contains("2:05"), "ending shows the run's stats")
	await _shot("%s_end" % tag)
	_press()
	for i in 30:
		await _seconds(0.1)
		if current_scene != cs and current_scene != null:
			break


func _press() -> void:
	var e := InputEventAction.new()
	e.action = "jump"
	e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventAction.new()
	u.action = "jump"
	u.pressed = false
	Input.parse_input_event(u)


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/%s.png" % name)


func _check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	_failed = _failed or not ok
