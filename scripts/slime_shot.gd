class_name SlimeShot
extends Area2D
## A glob of slime flying straight at Kira. Touching it sends her back to the entrance,
## unless she parries it: then it flies back to the slime that spat it and pops it.

const PARRY_REACH := 34.0 ## px from Kira's center where a parry catches the shot
const HIT_REACH := 12.0
const BACK_MULT := 1.6 ## a parried shot flies back faster

var velocity := Vector2.ZERO
var source: Node2D
var color := Color("#5fbf3f")
var parried := false
var _life := 6.0


func _ready() -> void:
	add_to_group("shot")
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	col.shape = circle
	add_child(col)
	body_entered.connect(_on_body)
	z_index = 5


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color("#0d0b0a"))
	draw_circle(Vector2.ZERO, 4.0, Color("#F4C430") if parried else color)
	draw_circle(Vector2(-1, -1), 1.5, Color(1, 1, 1, 0.8))


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if parried:
		for slime in get_tree().get_nodes_in_group("slime"):
			if slime.global_position.distance_to(global_position + Vector2(0, 10)) < 16.0:
				slime.die()
				queue_free()
				return
		return
	var player: Player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var d := global_position.distance_to(player.global_position)
	if player.parrying and d < PARRY_REACH:
		_reflect(player)
	elif d < HIT_REACH:
		Fx.play(get_parent(), "Smoke Bursts/symmetrical_smoke_burst_001/symmetrical_smoke_burst_001_small_brown", player.global_position)
		player.respawn()
		queue_free()


func _reflect(player: Player) -> void:
	parried = true
	var speed := velocity.length() * BACK_MULT
	if is_instance_valid(source):
		velocity = (source.global_position + Vector2(0, -10) - global_position).normalized() * speed
	else:
		velocity = -velocity * BACK_MULT
	_life = 4.0
	queue_redraw()
	player.parried()
	Fx.play(get_parent(), "Impacts/symmetrical_impact_001/symmetrical_impact_001_small_yellow", global_position)


func _on_body(body: Node) -> void:
	if body is Player:
		return # handled by distance above, so parry wins over contact
	Fx.play(get_parent(), "Impacts/symmetrical_impact_002/symmetrical_impact_002_small_blue", global_position)
	queue_free()
