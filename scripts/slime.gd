class_name Slime
extends Area2D
## Slime (32x32 Isometric slimes sheet): sees Kira, puffs up and spits a glob at her.
## Touching it sends Kira back. A parried glob flies back and pops it.
## Place it with its origin on the floor. Sheet: 15 columns x 16 rows, 4 rows per color.

enum Kind { GREEN, TEAL, PURPLE, ORANGE }
const COLORS := [Color("#5fbf3f"), Color("#3fbfa8"), Color("#8f5fbf"), Color("#d9702a")]
const IDLE_FRAMES := 5
const CHARGE_FRAMES := 9
const SHOOT_FRAME := 6 ## the "!" frame of the charge row

@export var kind := Kind.GREEN
@export var fire_interval := 1.8 ## seconds between shots
@export var shot_speed := 150.0
@export var sight := 360.0 ## only shoots when Kira is this close

var _cooldown := 1.0
var _charge := -1.0 # < 0 = idle, else seconds into the charge
var _t := 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("slime")
	_cooldown = fire_interval * 0.6


func _physics_process(delta: float) -> void:
	_t += delta
	var player: Player = get_tree().get_first_node_in_group("player")
	var row := int(kind) * 4
	if _charge >= 0.0:
		_charge += delta
		var f := mini(int(_charge * 15.0), CHARGE_FRAMES - 1)
		_sprite.frame = (row + 1) * 15 + f
		if f == SHOOT_FRAME and _charge - delta < SHOOT_FRAME / 15.0 and player:
			_shoot(player)
		if _charge >= CHARGE_FRAMES / 15.0:
			_charge = -1.0
			_cooldown = fire_interval
	else:
		_sprite.frame = row * 15 + int(_t * 6.0) % IDLE_FRAMES
		_cooldown -= delta
		if _cooldown <= 0.0 and player and global_position.distance_to(player.global_position) < sight:
			_charge = 0.0
	if player:
		_sprite.flip_h = player.global_position.x < global_position.x
		if overlaps_body(player):
			player.respawn()


func _shoot(player: Player) -> void:
	var shot := SlimeShot.new()
	shot.source = self
	shot.color = COLORS[kind]
	shot.position = position + Vector2(0, -12)
	shot.velocity = (player.global_position - global_position - Vector2(0, -12)).normalized() * shot_speed
	get_parent().add_child(shot)


func die() -> void:
	Fx.play(get_parent(), "Explosions/symmetrical_explosion_001/symmetrical_explosion_001_small_orange", global_position + Vector2(0, -10))
	queue_free()
