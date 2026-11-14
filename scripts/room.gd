class_name Room
extends Node2D
## One screen (640x360, 16 px tiles). Edit rooms in the Godot editor:
##   Terrain   TileMapLayer: rock, solid (no grip, wall jump only)
##   Moss      TileMapLayer: mossy rock, solid AND climbable (group "grecas")
##   Water     TileMapLayer: swamp water; touching it sends Kira back to Spawn
##   Rims, Backdrop  TileMapLayers: art only, no collision
##   Spawn     Marker2D at Kira's feet (entrance and respawn point)
##   Idol / Mushroom instances (scenes/props): drag them anywhere; edit Idol text in the Inspector
##   Decor     Sprite2Ds, art only
## Leaving the screen on the right or top loads the next room (scripts/game.gd).

const COL_TEXT := Color("#EFE6D5")
const COL_INK := Color("#2b2233")
const PAPER := preload("res://assets/third_party/paper_ui/holders/5.png") # Humble Gift Paper UI
const RISE := ["Te levantas.", "Otra vez.", "Caer también es subir.", "Melina espera.", "El pantano no te retiene."]

## Big card shown on entering (chapter title). Empty = none.
@export_multiline var title := ""
## Control hint shown only when the player looks stuck.
@export_multiline var stuck_hint := ""
@export var stuck_idle_time := 4.0
@export var stuck_room_time := 12.0
@export var stuck_deaths := 3

var spawn := Vector2(40, 308)

var _player: Player
var _deaths := 0
var _idle := 0.0
var _time := 0.0
var _water: Array[Area2D] = []
var _rise: Label
var _panel: Label
var _hint: Label


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.died.connect(_on_died)
	if has_node("Spawn"):
		spawn = $Spawn.position - Vector2(0, 12) # 12 = half player height
	_build_water()
	# Invisible wall left of the screen: the entrance doorway is open, the way back is not.
	var back := StaticBody2D.new()
	back.position = Vector2(-8, 180)
	back.add_child(_shape(Vector2(16, 400)))
	add_child(back)
	_panel = _make_label(Vector2(60, 14), 520, 16, true)
	_hint = _make_label(Vector2(60, 322), 520, 16, true)
	_hint.text = stuck_hint
	_rise = _make_label(Vector2(170, 150), 300, 32, true)
	if not title.is_empty():
		_show_title()


## One kill area per painted water cell.
func _build_water() -> void:
	if not has_node("Water"):
		return
	var layer: TileMapLayer = $Water
	for cell in layer.get_used_cells():
		var area := Area2D.new()
		area.position = layer.map_to_local(cell) + Vector2(0, 2)
		area.add_child(_shape(Vector2(14, 12)))
		add_child(area)
		_water.append(area)


func _physics_process(delta: float) -> void:
	if not _player:
		return
	for area in _water:
		if area.overlaps_body(_player):
			Fx.play(get_parent(), "Smoke Bursts/symmetrical_smoke_burst_001/symmetrical_smoke_burst_001_small_brown", _player.global_position)
			_player.respawn()
			break
	for m in get_tree().get_nodes_in_group("bouncer"):
		if is_ancestor_of(m) and m.overlaps_body(_player) and _player.velocity.y >= 0.0:
			Fx.play(get_parent(), "Impacts/symmetrical_impact_002/symmetrical_impact_002_small_blue", m.global_position)
			_player.bounce(m.speed)
	_rise.modulate.a = move_toward(_rise.modulate.a, 0.0, delta * 0.8)

	var reading := ""
	for idol in get_tree().get_nodes_in_group("readable"):
		if is_ancestor_of(idol) and idol.overlaps_body(_player):
			reading = idol.text
			idol.touched(_player)
	_panel.text = reading
	_fade(_panel, not reading.is_empty(), delta)

	_time += delta
	_idle = 0.0 if Input.is_anything_pressed() else _idle + delta
	var stuck := _idle >= stuck_idle_time or _time >= stuck_room_time or _deaths >= stuck_deaths
	_fade(_hint, stuck and not stuck_hint.is_empty() and reading.is_empty(), delta)


func _on_died() -> void:
	_deaths += 1
	_rise.text = RISE[(_deaths - 1) % RISE.size()]
	_rise.modulate.a = 1.5


# --- UI ----------------------------------------------------------------------

func _show_title() -> void:
	var label := _make_label(Vector2(120, 120), 400, 32, true)
	label.text = title
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)


func _make_label(pos: Vector2, width: float, font_size: int, boxed: bool) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(width, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.z_index = 10
	label.modulate.a = 0.0
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COL_INK if boxed else COL_TEXT)
	if boxed:
		var box := StyleBoxTexture.new()
		box.texture = PAPER
		box.set_texture_margin_all(8)
		box.set_content_margin_all(10)
		label.add_theme_stylebox_override("normal", box)
	add_child(label)
	return label


func _fade(node: CanvasItem, show: bool, delta: float) -> void:
	node.modulate.a = move_toward(node.modulate.a, 1.0 if show else 0.0, delta * 4.0)


func _shape(size: Vector2) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	return col
