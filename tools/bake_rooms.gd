extends SceneTree
## One-time converter: ASCII rooms (from tools/gen_prologue.py) -> editable scenes.
## godot --headless --path . -s res://tools/bake_rooms.gd
## Writes assets/tiles/world.tres (TileSet) and rewrites scenes/rooms/*.tscn with
## TileMapLayers (Backdrop, Terrain, Moss, Water, Rims), a Spawn marker, Idol and
## Mushroom instances and Decor sprites. After baking, edit the rooms in the Godot editor.
## WARNING: running it again overwrites hand edits (it re-reads the `layout` text).

const TILE := 16
const FOREST := "res://forest-nature-fantasy-tileset-free/Fantasy Swamp Forest/Free/Terrain_and_Props.png"
const DUNGEON := "res://assets/third_party/dungeon/dungeon.png"
const ROCK_X := 5 # orange-top rock: first inner column; rims spill to col-1, col+5 and row 7
const MOSS_X := 13 # grass-top rock
const WATER := Vector2i(4, 8)
const BACKDROP := [Vector2i(8, 2), Vector2i(9, 2), Vector2i(8, 3), Vector2i(9, 3), Vector2i(12, 2), Vector2i(12, 3), Vector2i(8, 5), Vector2i(9, 5)]
const DECOR := [Rect2(2, 369, 29, 15), Rect2(37, 365, 53, 19), Rect2(116, 488, 72, 56), Rect2(21, 466, 79, 78)]
const IDOL_HERMES := Rect2(33, 304, 28, 48)
enum { SRC_FOREST, SRC_DUNGEON }

var tileset: TileSet
var rows: PackedStringArray


func _initialize() -> void:
	tileset = _make_tileset()
	ResourceSaver.save(tileset, "res://assets/tiles/world.tres")
	tileset = load("res://assets/tiles/world.tres")
	for f in DirAccess.get_files_at("res://scenes/rooms"):
		if f.ends_with(".tscn"):
			_bake("res://scenes/rooms/" + f)
	quit()


func _make_tileset() -> TileSet:
	DirAccess.make_dir_recursive_absolute("res://assets/tiles")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var forest := TileSetAtlasSource.new()
	forest.texture = load(FOREST)
	forest.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(forest, SRC_FOREST) # before tiles: their collision needs the TileSet's physics layer
	for ox in [ROCK_X, MOSS_X]:
		for x in range(ox - 1, ox + 6):
			for y in range(1, 8):
				_tile(forest, Vector2i(x, y), x >= ox and x <= ox + 4 and y <= 6)
	_tile(forest, WATER, false)
	var dungeon := TileSetAtlasSource.new()
	dungeon.texture = load(DUNGEON)
	dungeon.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(dungeon, SRC_DUNGEON)
	for x in range(1, 4):
		for y in range(1, 4):
			_tile(dungeon, Vector2i(x, y), true)
	for c in BACKDROP:
		_tile(dungeon, c, false)
	return ts


func _tile(src: TileSetAtlasSource, at: Vector2i, solid: bool) -> void:
	src.create_tile(at)
	if solid:
		var data := src.get_tile_data(at, 0)
		data.add_collision_polygon(0)
		var h := TILE / 2.0
		data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))


func _prop(state: SceneState, name: String) -> Variant:
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == name:
			return state.get_node_property_value(0, i)
	return null


func _bake(path: String) -> void:
	var state := (load(path) as PackedScene).get_state()
	var layout: Variant = _prop(state, "layout")
	if layout == null:
		print("skip (already baked): ", path)
		return
	var texts: Array = _prop(state, "inscriptions") if _prop(state, "inscriptions") != null else []
	var dungeon: bool = _prop(state, "style") == "dungeon"
	rows = String(layout).strip_edges().split("\n")
	for y in rows.size():
		rows[y] = rows[y].strip_edges()

	var room := Node2D.new()
	room.name = state.get_node_name(0)
	room.set_script(load("res://scripts/room.gd"))
	room.set("title", _prop(state, "title") if _prop(state, "title") != null else "")
	room.set("stuck_hint", _prop(state, "stuck_hint") if _prop(state, "stuck_hint") != null else "")

	var backdrop := _layer(room, "Backdrop")
	var decor := Node2D.new()
	decor.name = "Decor"
	_add(room, decor)
	var terrain := _layer(room, "Terrain")
	var moss := _layer(room, "Moss")
	moss.add_to_group("grecas", true)
	var water := _layer(room, "Water")
	var rims := _layer(room, "Rims")

	var text_i := 0
	for y in rows.size():
		for x in rows[y].length():
			var c := rows[y][x]
			var cell := Vector2i(x, y)
			var feet := Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
			if dungeon:
				backdrop.set_cell(cell, SRC_DUNGEON, BACKDROP[absi(x * 7 + y * 13 + x * y) % BACKDROP.size()])
			match c:
				"#", "G":
					_solid_cell(terrain if c == "#" else moss, rims, cell, c, dungeon)
				"^":
					water.set_cell(cell, SRC_FOREST, WATER)
				"P":
					var spawn := Marker2D.new()
					spawn.name = "Spawn"
					spawn.position = feet
					_add(room, spawn)
				"B":
					var m: Node2D = load("res://scenes/props/mushroom.tscn").instantiate()
					m.position = feet
					_add(room, m)
				"A":
					var apple: Node2D = load("res://scenes/props/apple.tscn").instantiate()
					apple.position = feet
					_add(room, apple)
				"M":
					var slime: Node2D = load("res://scenes/props/slime.tscn").instantiate()
					slime.position = feet
					slime.set("kind", (x + y) % 4)
					_add(room, slime)
				"S", "H":
					var idol: Node2D = load("res://scenes/props/idol.tscn").instantiate()
					idol.position = feet
					idol.set("text", texts[text_i] if text_i < texts.size() else "")
					text_i += 1
					if c == "H":
						idol.name = "IdolHermes"
						idol.set("grants_dash", true)
						var spr: Sprite2D = idol.get_node("Sprite")
						spr.region_rect = IDOL_HERMES
						spr.offset = Vector2(0, -IDOL_HERMES.size.y / 2.0)
					_add(room, idol)
	_decorate(decor, hash(layout))

	var packed := PackedScene.new()
	packed.pack(room)
	ResourceSaver.save(packed, path)
	room.free()
	print("baked ", path)


func _layer(room: Node, name: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = name
	l.tile_set = tileset
	_add(room, l)
	return l


func _add(room: Node, child: Node) -> void:
	room.add_child(child, true)
	child.owner = room


func _cell(x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "#" # outside counts as rock: no rims on screen edges
	return rows[y][x]


func _solid(x: int, y: int) -> bool:
	return _cell(x, y) in ["#", "G"]


func _vary(x: int, y: int, n: int) -> int:
	return absi(x * 7 + y * 13 + x * y) % n


## Pick the block piece by its neighbours; rims go into the air around it.
func _solid_cell(layer: TileMapLayer, rims: TileMapLayer, cell: Vector2i, c: String, dungeon: bool) -> void:
	var x := cell.x
	var y := cell.y
	var up := _solid(x, y - 1)
	var down := _solid(x, y + 1)
	var left := _solid(x - 1, y)
	var right := _solid(x + 1, y)
	if dungeon and c == "#":
		var dx := 0 if not left else (2 if not right else 1)
		var dy := 0 if not up else (2 if not down else 1)
		layer.set_cell(cell, SRC_DUNGEON, Vector2i(1 + dx, 1 + dy))
		return
	var ox := MOSS_X if c == "G" else ROCK_X
	var row := 1 if not up else (6 if not down else 3 + _vary(x, y, 2))
	var col := ox if not left else (ox + 4 if not right else ox + 1 + _vary(x, y, 3))
	if up and down and left and right:
		col = ox
	layer.set_cell(cell, SRC_FOREST, Vector2i(col, row))
	if not left:
		rims.set_cell(cell + Vector2i.LEFT, SRC_FOREST, Vector2i(ox - 1, row if up else 2))
	if not right:
		rims.set_cell(cell + Vector2i.RIGHT, SRC_FOREST, Vector2i(ox + 5, row if up else 2))
	if not down:
		rims.set_cell(cell + Vector2i.DOWN, SRC_FOREST, Vector2i(col, 7))


## Rocks, mushrooms and trees on open floor, seeded by the layout.
func _decorate(decor: Node2D, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tex: Texture2D = load(FOREST)
	for y in range(3, rows.size()):
		var x := 1
		while x < rows[y].length() - 6:
			var ok := true
			for i in 6:
				if _cell(x + i, y) != "#" or _cell(x + i, y - 1) != "." or _cell(x + i, y - 2) != "." or _cell(x + i, y - 3) != ".":
					ok = false
			if ok and rng.randf() < 0.18:
				var r: Rect2 = DECOR[rng.randi() % DECOR.size()]
				if r.size.y <= 2 * TILE or (_cell(x, y - 6) == "." and _cell(x + 5, y - 6) == "."):
					var s := Sprite2D.new()
					s.texture = tex
					s.region_enabled = true
					s.region_rect = r
					s.centered = false
					s.position = Vector2(x * TILE, y * TILE + 2 - r.size.y)
					decor.add_child(s, true)
					s.owner = decor.owner
					x += 6
					continue
			x += 1
