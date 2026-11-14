extends SceneTree
## Rendered playthrough of the tutorial zone with real key events.
## Proves every room is solvable with the current physics and saves one PNG per room.
## godot --path . -s res://tests/tutorial_test.gd   -> tests/shots/room_XX.png
## Add --headless for logic only: no window, so focus loss can't release held keys.

const TIMEOUT := 600 # physics frames per room

var game: Node
var p: Player
var _failed := false
var _held := {} # keys the bot holds; re-pressed if a window focus loss releases them


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	while current_scene == null:
		await process_frame
	game = current_scene
	p = game.player
	var bots := [_r_walk, _r_jump, _r_spikes, _r_climb, _r_walljump, _r_dash, _r_dash_up, _r_recharge, _r_gate, _r_bounce,
			_r_auto, _r_auto, _r_auto, _r_auto, _r_auto, _r_auto, _r_auto, _r_slime, _r_auto, _r_auto, _r_auto]
	for i in bots.size():
		await _frames(20)
		await _shot("room_%02d" % (i + 1))
		await bots[i].call()
		_release_all()
		var ok: bool = game.room_index == i + 1
		_check(ok, "room %d solved" % (i + 1))
		if not ok:
			break
	await _frames(20)
	await _shot("room_%02d" % (game.room_index + 1))
	var falls: int = game.falls
	if not _failed:
		await _r_final()
	print("falls in the whole run: %d" % falls)
	print("FAIL" if _failed else "ALL TUTORIAL ROOMS SOLVED")
	quit(1 if _failed else 0)


# --- room bots ---------------------------------------------------------------

func _r_walk() -> void:
	await _tap(KEY_X)
	await _frames(2)
	_check(p.dashes == p.max_dashes and p.velocity == Vector2.ZERO, "no dash before taking the sandals")
	_key(KEY_RIGHT, true)
	await _until(func(): return p.global_position.x >= 110.0)
	await _shot("read_01_stele")
	_check(game._room._panel.text.contains("Melina"), "stele text shows when near")
	await _until_room_change()


func _r_jump() -> void:
	await _r_route()


func _r_spikes() -> void:
	await _r_route()


## Hold right; full jump at a wall ahead or at the edge of a gap.
func _r_route() -> void:
	var start: int = game.room_index
	_key(KEY_RIGHT, true)
	for i in TIMEOUT:
		if game.room_index != start:
			return
		if p.is_on_floor() and (p.test_move(p.global_transform, Vector2(12, 0)) or _edge_ahead()):
			await _jump(20)
		await _frames(1)


func _r_climb() -> void:
	# Smooth marble (left wall) gives no grip.
	_key(KEY_LEFT, true)
	_key(KEY_Z, true)
	await _frames(30)
	_check(not p.is_climbing, "smooth marble wall cannot be grabbed")
	_key(KEY_LEFT, false)
	_key(KEY_Z, false)
	_key(KEY_RIGHT, true)
	await _until(func(): return p.global_position.x >= 262.0)
	await _shot("read_04_stele")
	_key(KEY_Z, true)
	_key(KEY_UP, true)
	await _until(func(): return p.is_climbing)
	_check(p.is_climbing, "greca wall can be grabbed")
	await _frames(12)
	await _shot("climb_04")
	_key(KEY_Z, false)
	_key(KEY_UP, false)
	_key(KEY_RIGHT, true)
	_key(KEY_Z, true)
	_key(KEY_UP, true)
	await _until(func(): return p.global_position.y < 150.0)
	await _jump(10)
	_key(KEY_Z, false)
	_key(KEY_UP, false)
	await _until_room_change()


func _r_walljump() -> void:
	# Hop through the hall, bounce up the chimney between its smooth walls, run out along the corridor.
	var toward := 1
	_key(KEY_RIGHT, true)
	for i in 900:
		if game.room_index == 5:
			return
		if p.is_on_floor() and p.global_position.y < 120.0:
			_key(KEY_LEFT, false)
			_key(KEY_RIGHT, true)
		elif p.is_on_floor():
			toward = 1
			_key(KEY_LEFT, false)
			_key(KEY_RIGHT, true)
			await _jump(12)
			continue
		else:
			var wall := p._wall_dir()
			if wall != 0 and wall == toward and p.velocity.y > -80.0 and p.global_position.x > 400.0: # in the chimney
				toward = -wall
				_key(KEY_RIGHT, toward == 1)
				_key(KEY_LEFT, toward == -1)
				await _jump(12)
				continue
		await _frames(1)


func _r_dash() -> void:
	_key(KEY_RIGHT, true)
	await _until(func(): return p.global_position.x >= 226.0)
	await _shot("read_06_altar")
	_check(p.dash_unlocked, "altar grants the sandals")
	await _until(_edge_ahead)
	_key(KEY_C, true)
	await _frames(14)
	await _tap(KEY_X)
	_key(KEY_C, false)
	await _until_room_change()


func _r_dash_up() -> void:
	_key(KEY_RIGHT, true)
	await _until(func(): return p.global_position.x >= 350.0)
	_key(KEY_RIGHT, false)
	_key(KEY_C, true)
	await _frames(14)
	_key(KEY_UP, true)
	await _tap(KEY_X)
	_key(KEY_C, false)
	_key(KEY_UP, false)
	await _frames(6)
	_key(KEY_RIGHT, true)
	await _until_room_change()


func _r_recharge() -> void:
	for i in 2:
		_key(KEY_RIGHT, true)
		await _until(_edge_ahead)
		_key(KEY_C, true)
		await _frames(14)
		await _tap(KEY_X)
		_key(KEY_C, false)
		_key(KEY_RIGHT, false) # let air friction stop Kira on the island
		await _frames(4)
		await _until(func(): return p.is_on_floor())
	_key(KEY_RIGHT, true)
	await _until_room_change()


## Grab the carved pillars and climb; the climb hops over the top edge.
func _r_gate() -> void:
	var start: int = game.room_index
	_key(KEY_RIGHT, true)
	for i in TIMEOUT * 2:
		if game.room_index != start:
			return
		var grab: bool = p._grabbable(1)
		_key(KEY_Z, grab)
		_key(KEY_UP, grab)
		await _frames(1)


## Last room: bronze shields bounce Kira up three terraces to the final stele.
func _r_bounce() -> void:
	_key(KEY_RIGHT, true)
	var bounced := false
	var start: int = game.room_index
	for i in TIMEOUT:
		bounced = bounced or p.velocity.y < -500.0
		if game.room_index != start:
			break
		await _frames(1)
	_check(bounced, "mushroom bounces Kira")


## Generic route for the later rooms: hold right; climb moss; at a wall jump; at an edge
## walk off (deep drop), jump (landing within 6 tiles) or jump + dash (wider pools).
func _r_auto() -> void:
	var start: int = game.room_index
	_key(KEY_RIGHT, true)
	for i in TIMEOUT * 3:
		if game.room_index != start or game._ended:
			return
		if _incoming():
			await _tap(KEY_A)
			continue
		_key(KEY_RIGHT, not _slime_ahead())
		var grab: bool = p._grabbable(1) or p.is_climbing
		_key(KEY_Z, grab)
		_key(KEY_UP, grab)
		if p.is_on_floor() and not grab:
			if p.test_move(p.global_transform, Vector2(12, 0)):
				await _jump(20)
				continue
			var drop := _drop(24.0)
			if _edge_ahead() and (drop < 40.0 or drop == 999.0):
				var land := _landing()
				if land > 0.0 and land <= 96.0:
					await _jump(20)
				else:
					_key(KEY_C, true)
					await _frames(14)
					await _tap(KEY_X)
					_key(KEY_C, false)
				continue
		await _frames(1)


## First slime: wait in front of it, parry its glob back, walk on.
func _r_slime() -> void:
	var start: int = game.room_index
	var falls: int = game.falls
	_check(get_nodes_in_group("slime").size() > 0, "slime in the tunnel")
	for i in TIMEOUT:
		if get_nodes_in_group("slime").is_empty():
			break
		if _incoming():
			await _tap(KEY_A)
			continue
		await _frames(1)
	_check(get_nodes_in_group("slime").is_empty() and game.falls == falls, "parried glob popped the slime, no hit taken")
	await _r_auto()
	_check(game.room_index != start, "parry popped the slime and opened the tunnel")


## Summit: bounce up to the Ambrosia Apple; taking it plays the ending cutscene.
func _r_final() -> void:
	_check(game._room.title.contains("Caídas"), "fall counter on the last title")
	await _r_auto()
	_release_all()
	_check(game._ended, "took the Ambrosia Apple")
	await _shot("room_22_apple")
	for i in TIMEOUT:
		if current_scene and current_scene.name == "Ending":
			break
		await physics_frame
	_check(current_scene != null and current_scene.name == "Ending", "ending cutscene plays")


## A glob flying at Kira, about to hit: time to parry.
func _incoming() -> bool:
	for shot in get_nodes_in_group("shot"):
		var to_kira: Vector2 = p.global_position - shot.global_position
		if not shot.parried and to_kira.length() < 30.0 and shot.velocity.dot(to_kira) > 0.0:
			return true
	return false


## A live slime on Kira's path just ahead: wait and parry instead of walking into it.
func _slime_ahead() -> bool:
	for slime in get_nodes_in_group("slime"):
		var d: Vector2 = slime.global_position - (p.global_position + Vector2(0, 12))
		if d.x > 0.0 and d.x < 170.0 and absf(d.y) < 60.0:
			return true
	return false


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.exclude = [p.get_rid()]
	return p.get_world_2d().direct_space_state.intersect_ray(q)


## Drop from Kira's feet to the ground `dx` px ahead (999 = nothing, or swamp water).
func _drop(dx: float) -> float:
	var feet := p.global_position + Vector2(0, 12)
	var hit := _ray(feet + Vector2(dx, -4), feet + Vector2(dx, 400))
	if not hit:
		return 999.0
	var water: TileMapLayer = game._room.get_node("Water")
	if water.get_cell_source_id(water.local_to_map(hit.position - Vector2(0, 8))) != -1:
		return 999.0
	return hit.position.y - feet.y


## Distance to the nearest ground ahead at about Kira's height (-3.5 .. +2.5 tiles); 0 = none.
func _landing() -> float:
	var feet := p.global_position + Vector2(0, 12)
	for dx in range(32, 200, 8):
		var hit := _ray(feet + Vector2(dx, -56), feet + Vector2(dx, 40))
		if hit and hit.position.y > feet.y - 56:
			return dx
	return 0.0



## On the floor with no floor 6 px ahead: a pit starts here.
func _edge_ahead() -> bool:
	return p.is_on_floor() and not p.test_move(p.global_transform.translated(Vector2(12, 0)), Vector2(0, 8))


func _jump(hold: int) -> void:
	_key(KEY_C, true)
	await _frames(hold)
	_key(KEY_C, false)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)


func _key(code: Key, down: bool) -> void:
	if down:
		_held[code] = true
	else:
		_held.erase(code)
	_send(code, down)


func _send(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _release_all() -> void:
	for k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_C, KEY_X, KEY_Z, KEY_A]:
		_key(k, false)


## One physics frame; then restore held keys that focus loss released.
func _tick() -> void:
	await physics_frame
	for k in _held:
		if not Input.is_physical_key_pressed(k):
			_send(k, true)


func _frames(n: int) -> void:
	for i in n:
		await _tick()


func _until(cond: Callable) -> void:
	for i in TIMEOUT:
		if cond.call():
			return
		await _tick()


func _until_room_change() -> void:
	var start: int = game.room_index
	await _until(func(): return game.room_index != start)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return # no frames are drawn; run without --headless to get PNGs
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/%s.png" % name)


func _check(ok: bool, msg: String) -> void:
	var where := "  pos=%s room=%d" % [p.global_position, game.room_index] if is_instance_valid(p) and is_instance_valid(game) else ""
	print(("PASS " if ok else "FAIL ") + msg + where)
	_failed = _failed or not ok
