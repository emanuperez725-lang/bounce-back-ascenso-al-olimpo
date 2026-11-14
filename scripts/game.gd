extends Node2D
## Loads rooms in order. Leaving the screen on the right or top goes to the next room.

const SCREEN := Vector2(640, 360)
const BG := "res://forest-nature-fantasy-tileset-free/Fantasy Swamp Forest/Free/BG_%d/BG_%d.png"

@export var rooms: Array[PackedScene] = []

@onready var player: Player = $Player

var room_index := -1
var _room: Room
var _bg: Array[Sprite2D] = []
var _wipe: ShaderMaterial
var falls := 0 # bounce back: every fall counts, every rise too
var play_time := 0.0
var _ended := false


func _ready() -> void:
	add_to_group("game")
	# Swamp forest behind every room (Fantasy Swamp Forest BG_3 far .. BG_1 near).
	RenderingServer.set_default_clear_color(Color("#d6e6f0"))
	var bg := CanvasLayer.new()
	bg.layer = -1
	for i in [3, 2, 1]:
		var s := Sprite2D.new()
		s.texture = load(BG % [i, i])
		s.centered = false
		s.position.y = SCREEN.y - s.texture.get_height()
		_bg.append(s)
		bg.add_child(s)
	add_child(bg)
	add_child(_motes())
	add_child(_transition())
	player.died.connect(func() -> void: falls += 1)
	load_room(0)


## Room wipe (scripts/shaders/transition.gdshader): dots shrink away from left to right.
func _transition() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var rect := ColorRect.new()
	rect.size = SCREEN
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe = ShaderMaterial.new()
	_wipe.shader = preload("res://scripts/shaders/transition.gdshader")
	var sweep := GradientTexture2D.new() # 0 at the left edge, 1 at the right
	sweep.gradient = Gradient.new()
	var dot := GradientTexture2D.new() # round dot: white center, black rim
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.gradient = Gradient.new()
	dot.gradient.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	_wipe.set_shader_parameter("base_color", Color("#1d1a26"))
	_wipe.set_shader_parameter("node_resolution", SCREEN)
	_wipe.set_shader_parameter("gradient_texture", sweep)
	_wipe.set_shader_parameter("shape_texture", dot)
	_wipe.set_shader_parameter("shape_tiling", 12.0)
	_wipe.set_shader_parameter("factor", 0.0)
	rect.material = _wipe
	layer.add_child(rect)
	return layer


## Slow golden motes drifting up through every room.
func _motes() -> CPUParticles2D:
	var m := CPUParticles2D.new()
	m.amount = 24
	m.lifetime = 8.0
	m.preprocess = 8.0
	m.position = Vector2(SCREEN.x / 2.0, SCREEN.y + 4.0)
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.emission_rect_extents = Vector2(SCREEN.x / 2.0, 4.0)
	m.direction = Vector2.UP
	m.spread = 15.0
	m.gravity = Vector2.ZERO
	m.initial_velocity_min = 12.0
	m.initial_velocity_max = 28.0
	m.scale_amount_min = 1.0
	m.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color("#F4C430", 0.0))
	fade.add_point(0.2, Color("#F4C430", 0.9))
	fade.add_point(0.8, Color("#EFE6D5", 0.7))
	fade.set_color(fade.get_point_count() - 1, Color("#EFE6D5", 0.0))
	m.color_ramp = fade
	m.z_index = 5
	return m


func _physics_process(delta: float) -> void:
	if not _ended:
		play_time += delta
	var p := player.global_position
	if p.x > SCREEN.x or p.y < -24.0:
		load_room(room_index + 1)


func load_room(i: int) -> void:
	if i >= rooms.size():
		return
	if _room:
		remove_child(_room)
		_room.queue_free()
	room_index = i
	# Each room shows a further stretch of the forest; near layers move more.
	for j in _bg.size():
		var span := _bg[j].texture.get_width() - SCREEN.x
		_bg[j].position.x = -fmod(i * (60.0 + 60.0 * j), span)
	_room = rooms[i].instantiate()
	if i == rooms.size() - 1:
		_room.title += "\nCaídas: %d  ·  Levantadas: %d" % [falls, falls]
	add_child(_room)
	move_child(_room, 0)
	player.spawn = _room.spawn
	player.respawn(false)
	if i > 0:
		_wipe.set_shader_parameter("factor", 1.0)
		create_tween().tween_method(func(f: float) -> void: _wipe.set_shader_parameter("factor", f), 1.0, 0.0, 0.6)


## The Ambrosia Apple was taken: freeze Kira, fade out, play scenes/ending.tscn with the run's stats.
func ending() -> void:
	if _ended:
		return
	_ended = true
	player.set_physics_process(false)
	get_tree().root.set_meta("stats", {"falls": falls, "parries": player.parries, "time": play_time})
	_wipe.set_shader_parameter("factor", 0.0)
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_method(func(f: float) -> void: _wipe.set_shader_parameter("factor", f), 0.0, 1.0, 0.8)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file("res://scenes/ending.tscn"))
