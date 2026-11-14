extends SceneTree
## Fast sanity check: every room in game.tscn loads, has a Spawn and ground under it.
## godot --headless --path . -s res://tests/rooms_load_test.gd

func _initialize() -> void:
	var game: PackedScene = load("res://scenes/game.tscn")
	var g := game.instantiate()
	var failed := false
	for i in g.rooms.size():
		var room: Node = g.rooms[i].instantiate()
		var ok: bool = room.has_node("Spawn") and room.has_node("Terrain")
		print(("PASS " if ok else "FAIL ") + "room %d %s" % [i + 1, room.name])
		failed = failed or not ok
		room.free()
	g.free()
	print("FAIL" if failed else "ALL ROOMS LOAD")
	quit(1 if failed else 0)
