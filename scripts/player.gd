class_name Player
extends CharacterBody2D
## Kira's controller: a three-state machine (NORMAL, CLIMB, DASH).
## Tuning numbers are Celeste's published Player constants scaled x2 for 16 px tiles
## (Celeste uses 8 px). Units: px, px/s, px/s^2 at 640x360.

enum State { NORMAL, CLIMB, DASH }

@export_group("Run")
@export var max_run := 180.0 ## MaxRun
@export var run_accel := 2000.0 ## RunAccel (also used to stop)
@export var run_reduce := 800.0 ## RunReduce: slowdown above max_run in the held direction
@export_range(0.0, 1.0) var air_mult := 0.65 ## AirMult

@export_group("Gravity")
@export var gravity := 1800.0 ## Gravity
@export var half_grav_threshold := 80.0 ## HalfGravThreshold: floaty apex while jump is held
@export var max_fall := 320.0 ## MaxFall
@export var fast_max_fall := 480.0 ## FastMaxFall (hold down)
@export var fast_max_accel := 600.0 ## FastMaxAccel

@export_group("Jump")
@export var jump_speed := 210.0 ## JumpSpeed
@export var jump_h_boost := 80.0 ## JumpHBoost
@export var var_jump_time := 0.2 ## VarJumpTime: hold jump to keep rising speed
@export var coyote_time := 0.1 ## JumpGraceTime
@export var jump_buffer_time := 0.08 ## Celeste's jump input buffer

@export_group("Wall")
@export var wall_jump_check := 6.0 ## WallJumpCheckDist
@export var wall_jump_h_speed := 260.0 ## WallJumpHSpeed
@export var wall_jump_force_time := 0.16 ## WallJumpForceTime
@export var wall_slide_start_max := 40.0 ## WallSlideStartMax
@export var wall_slide_time := 1.2 ## WallSlideTime

@export_group("Climb")
@export var climb_check := 4.0 ## ClimbCheckDist
@export var max_stamina := 110.0 ## ClimbMaxStamina
@export var climb_tired_threshold := 20.0 ## ClimbTiredThreshold
@export var climb_up_cost := 100.0 / 2.2 ## ClimbUpCost, stamina/s
@export var climb_still_cost := 100.0 / 10.0 ## ClimbStillCost, stamina/s
@export var climb_jump_cost := 110.0 / 4.0 ## ClimbJumpCost
@export var climb_up_speed := 90.0 ## ClimbUpSpeed
@export var climb_down_speed := 160.0 ## ClimbDownSpeed
@export var climb_slip_speed := 60.0 ## ClimbSlipSpeed: slide down when exhausted
@export var climb_accel := 1800.0 ## ClimbAccel
@export var climb_no_move_time := 0.1 ## ClimbNoMoveTime: brief stick on grab
@export var climb_hop := Vector2(200.0, 240.0) ## Hop over the top edge of a wall
@export var climb_hop_force_time := 0.2

@export_group("Dash")
@export var dash_speed := 480.0 ## DashSpeed
@export var end_dash_speed := 320.0 ## EndDashSpeed
@export_range(0.0, 1.0) var end_dash_up_mult := 0.75 ## EndDashUpMult
@export var dash_time := 0.15 ## DashTime
@export var dash_cooldown := 0.2 ## DashCooldown
@export var dash_refill_cooldown := 0.1 ## DashRefillCooldown
@export var hitstop_time := 0.05 ## freeze frames on dash start
@export var max_dashes := 1

@export_group("Parry")
## Press parry (A / gamepad Y) just before a slime glob hits: it flies back at the slime.
@export var parry_time := 0.15 ## active window
@export var parry_cooldown := 0.35 ## no mashing
@export var parry_hop := 260.0 ## a parry in the air bounces Kira up a little

@export_group("Corner correction")
@export var upward_corner_correction := 8 ## UpwardCornerCorrection
@export var dash_corner_correction := 8 ## DashCornerCorrection

@export_group("Sandals of Hermes")
## False until Kira takes the sandals from the altar (prologue).
@export var dash_unlocked := true
## Only bodies in this group can be grabbed (carved meander walls).
@export var grab_group := &"grecas"

## Sprite sheets (tools/gen_kira.py), drawn x2 on 16 px tiles. Arm wraps show the dash: gold = ready, white = spent.
const SHEET_READY := preload("res://assets/sprites/kira.png")
const SHEET_SPENT := preload("res://assets/sprites/kira_spent.png")
const SHEET_BAREFOOT := preload("res://assets/sprites/kira_barefoot.png")
## Frame order of the sheet (tools/gen_kira.py FRAMES, from the 2D Platformer Character Template).
enum { F_IDLE = 0, F_RUN = 1, F_JUMP = 10, F_PEAK = 11, F_FALL = 12, F_DASH = 14, F_WALLSLIDE = 16, F_LAND = 17, F_CLIMB = 19 }
const LAND_TIME := 0.08
const COLOR_TIRED := Color(1.0, 0.55, 0.55)

signal died

@onready var _sprite: Sprite2D = $Sprite

var state := State.NORMAL
var is_climbing: bool:
	get: return state == State.CLIMB
var facing := 1
var dashes := 1
var stamina := 110.0
var spawn := Vector2.ZERO

# input, read once per frame
var _dir := Vector2.ZERO
var _jump_held := false

# timers (seconds, count down to 0)
var _coyote := 0.0
var _jump_buffer := 0.0
var _var_jump := 0.0
var _var_jump_speed := 0.0
var _force_move := 0.0
var _force_move_x := 0
var _wall_slide := 0.0
var _climb_no_move := 0.0
var _dash := 0.0
var _dash_cooldown := 0.0
var _dash_refill := 0.0
var _dash_dir := Vector2.ZERO
var _land := 0.0
var _was_on_floor := true
var parries := 0 ## globs sent back, for the ending stats
var _parry := 0.0
var _parry_cd := 0.0
var parrying: bool:
	get: return _parry > 0.0


func _ready() -> void:
	add_to_group("player")
	spawn = global_position
	dashes = max_dashes
	stamina = max_stamina


func _physics_process(delta: float) -> void:
	_read_input()
	_tick(delta)
	match state:
		State.NORMAL: _normal(delta)
		State.CLIMB: _climb(delta)
		State.DASH: _dashing(delta)
	_move(delta)
	_update_sprite()


func _read_input() -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dir = Vector2(signf(v.x), signf(v.y)) # digital 8-way
	_jump_held = Input.is_action_pressed("jump")
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	if Input.is_action_just_pressed("parry") and _parry_cd <= 0.0:
		_parry = parry_time
		_parry_cd = parry_cooldown
		var swing := Fx.play(get_parent(), "Impacts/directional_impact_002/directional_impact_002_small_white", global_position + Vector2(18 * facing, 0))
		swing.flip_h = facing < 0


func _tick(delta: float) -> void:
	for t in ["_coyote", "_jump_buffer", "_var_jump", "_force_move", "_climb_no_move", "_dash_cooldown", "_dash_refill", "_parry", "_parry_cd"]:
		set(t, maxf(get(t) - delta, 0.0))
	if is_on_floor() and state != State.DASH:
		_coyote = coyote_time
		_wall_slide = wall_slide_time
		stamina = max_stamina
		if _dash_refill <= 0.0:
			dashes = max_dashes


func _set_state(s: State) -> void:
	state = s
	match s:
		State.CLIMB:
			velocity.x = 0.0
			velocity.y *= 0.2
			_climb_no_move = climb_no_move_time
		State.DASH:
			_begin_dash()


func _move_x() -> int:
	return _force_move_x if _force_move > 0.0 else int(_dir.x)


# --- NORMAL ------------------------------------------------------------------

func _normal(delta: float) -> void:
	if _can_dash():
		_set_state(State.DASH)
		return
	var mx := _move_x()
	if mx != 0:
		facing = mx
	if Input.is_action_pressed("grab") and velocity.y >= 0.0 and stamina > 0.0 and _grabbable(facing):
		_set_state(State.CLIMB)
		return

	# Horizontal: accelerate to max_run; above it in the same direction, bleed off slowly.
	var mult := 1.0 if is_on_floor() else air_mult
	if absf(velocity.x) > max_run and signf(velocity.x) == mx:
		velocity.x = move_toward(velocity.x, max_run * mx, run_reduce * mult * delta)
	else:
		velocity.x = move_toward(velocity.x, max_run * mx, run_accel * mult * delta)

	# Vertical: fast fall, wall slide, half gravity at the apex.
	var fall := max_fall
	if _dir.y > 0.0 and velocity.y >= max_fall:
		fall = move_toward(velocity.y, fast_max_fall, fast_max_accel * delta)
	if mx != 0 and mx == facing and velocity.y > 0.0 and _wall_slide > 0.0 and _wall_at(mx, 1.0):
		fall = lerpf(max_fall, wall_slide_start_max, _wall_slide / wall_slide_time)
		_wall_slide = maxf(_wall_slide - delta, 0.0)
	if not is_on_floor():
		var g := 0.5 if absf(velocity.y) < half_grav_threshold and _jump_held else 1.0
		velocity.y = move_toward(velocity.y, fall, gravity * g * delta)

	# Variable jump: holding jump keeps the launch speed for var_jump_time.
	if _var_jump > 0.0:
		if _jump_held:
			velocity.y = minf(velocity.y, _var_jump_speed)
		else:
			_var_jump = 0.0

	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_jump()
		elif _wall_at(1, wall_jump_check):
			_wall_jump(-1)
		elif _wall_at(-1, wall_jump_check):
			_wall_jump(1)


func _jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	velocity.x += jump_h_boost * _move_x()
	velocity.y = -jump_speed
	_var_jump = var_jump_time
	_var_jump_speed = velocity.y


func _wall_jump(dir: int) -> void:
	_jump_buffer = 0.0
	_force_move = wall_jump_force_time
	_force_move_x = dir
	facing = dir
	velocity.x = wall_jump_h_speed * dir
	velocity.y = -jump_speed
	_var_jump = var_jump_time
	_var_jump_speed = velocity.y


# --- CLIMB -------------------------------------------------------------------

func _climb(delta: float) -> void:
	if _can_dash():
		_set_state(State.DASH)
		return
	if not Input.is_action_pressed("grab") or not _grabbable(facing):
		# Climbed past the top edge while pushing up: hop onto the ledge.
		if _dir.y < 0.0 and Input.is_action_pressed("grab") and not _wall_at(facing, climb_check):
			velocity = Vector2(climb_hop.x * facing, -climb_hop.y)
			_force_move = climb_hop_force_time
			_force_move_x = facing
		_set_state(State.NORMAL)
		return
	if _jump_buffer > 0.0:
		if int(_dir.x) == -facing:
			_wall_jump(-facing)
		else:
			stamina -= climb_jump_cost
			_jump()
		_set_state(State.NORMAL)
		return

	velocity.x = 0.0
	var target := 0.0
	if stamina <= 0.0:
		target = climb_slip_speed
	elif _climb_no_move > 0.0:
		target = 0.0
	elif _dir.y < 0.0:
		target = -climb_up_speed
		stamina -= climb_up_cost * delta
	elif _dir.y > 0.0:
		target = climb_down_speed
	else:
		stamina -= climb_still_cost * delta
	velocity.y = move_toward(velocity.y, target, climb_accel * delta)


# --- DASH --------------------------------------------------------------------

func _can_dash() -> bool:
	return dash_unlocked and Input.is_action_just_pressed("dash") and dashes > 0 and _dash_cooldown <= 0.0


func _begin_dash() -> void:
	dashes -= 1
	_dash = dash_time
	_dash_cooldown = dash_cooldown
	_dash_refill = dash_refill_cooldown
	_var_jump = 0.0
	_force_move = 0.0
	_dash_dir = (_dir if _dir != Vector2.ZERO else Vector2(facing, 0.0)).normalized()
	if _dash_dir.x != 0.0:
		facing = int(signf(_dash_dir.x))
	var before := velocity
	velocity = _dash_dir * dash_speed
	# Keep extra horizontal momentum when dashing the way you were already going fast.
	if signf(before.x) == signf(velocity.x) and absf(before.x) > absf(velocity.x):
		velocity.x = before.x
	_hitstop()


func _dashing(delta: float) -> void:
	_dash -= delta
	if _dash > 0.0:
		return
	if _dash_dir.y <= 0.0:
		velocity = _dash_dir * end_dash_speed
		if velocity.y < 0.0:
			velocity.y *= end_dash_up_mult
	_set_state(State.NORMAL)


func _hitstop() -> void:
	if hitstop_time <= 0.0:
		return
	Engine.time_scale = 0.0
	# ignore_time_scale = true so the timer runs while the game is frozen.
	await get_tree().create_timer(hitstop_time, true, false, true).timeout
	Engine.time_scale = 1.0


# --- movement and corner correction -----------------------------------------

func _move(delta: float) -> void:
	if velocity.y < 0.0:
		_correct(Vector2(0.0, velocity.y * delta), Vector2.RIGHT, upward_corner_correction)
	if state == State.DASH and _dash_dir.y == 0.0:
		_correct(Vector2(velocity.x * delta, 0.0), Vector2.UP, dash_corner_correction)
	move_and_slide()
	if global_position.y > get_viewport_rect().size.y + 32.0:
		respawn()


## If `step` would hit something, slide up to `reach` px along `axis` (either sign) to clear it.
func _correct(step: Vector2, axis: Vector2, reach: int) -> void:
	if not test_move(global_transform, step):
		return
	for i in range(1, reach + 1):
		for s in [-1, 1]:
			var shift: Vector2 = axis * i * s
			if not test_move(global_transform, shift) and not test_move(global_transform.translated(shift), step):
				position += shift
				return


func _wall_at(side: int, dist: float) -> bool:
	return test_move(global_transform, Vector2(side * dist, 0.0))


func _grabbable(side: int) -> bool:
	var hit := move_and_collide(Vector2(side * climb_check, 0.0), true, safe_margin, true)
	return hit != null and (hit.get_collider() as Node).is_in_group(grab_group)


## -1 / 1 for a wall within climb reach (facing side first), 0 for none.
func _wall_dir() -> int:
	for side in [facing, -facing]:
		if _wall_at(side, climb_check):
			return side
	return 0


## A glob was parried: dash back, a small hop in the air, a beat of hitstop.
func parried() -> void:
	parries += 1
	dashes = max_dashes
	if not is_on_floor() and state != State.CLIMB:
		velocity.y = minf(velocity.y, -parry_hop)
	_hitstop()


## Bronze shield: launch up much higher than a jump and give the dash back.
func bounce(speed: float) -> void:
	_set_state(State.NORMAL)
	velocity.y = -speed
	_var_jump = 0.0
	_jump_buffer = 0.0
	dashes = max_dashes


func respawn(is_death := true) -> void:
	if is_death:
		died.emit()
	global_position = spawn
	velocity = Vector2.ZERO
	state = State.NORMAL
	dashes = max_dashes
	stamina = max_stamina
	_force_move = 0.0
	_jump_buffer = 0.0
	_var_jump = 0.0
	_dash = 0.0
	_parry = 0.0


func _update_sprite() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_land = LAND_TIME
	_was_on_floor = on_floor
	_land = maxf(_land - get_physics_process_delta_time(), 0.0)

	var frame := F_IDLE
	if state == State.DASH:
		frame = F_DASH + int(t * 20.0) % 2
	elif state == State.CLIMB:
		frame = F_CLIMB + (int(t * 8.0) % 4 if velocity.y < 0.0 else 0)
	elif not on_floor:
		if _dir.x == facing and velocity.y > 0.0 and _wall_at(facing, 1.0):
			frame = F_WALLSLIDE
		elif absf(velocity.y) < half_grav_threshold:
			frame = F_PEAK
		elif velocity.y < 0.0:
			frame = F_JUMP
		else:
			frame = F_FALL + int(t * 10.0) % 2
	elif _land > 0.0:
		frame = F_LAND
	elif absf(velocity.x) > 20.0:
		frame = F_RUN + int(t * 14.0) % 8
	if _parry > 0.0 and state == State.NORMAL:
		frame = F_DASH + 1 # strike pose
	_sprite.frame = frame
	# Template wall poses face away from the wall: flip them so the hands grip it.
	_sprite.flip_h = (facing > 0) if frame >= F_CLIMB or frame == F_WALLSLIDE else (facing < 0)
	_sprite.texture = SHEET_BAREFOOT if not dash_unlocked else (SHEET_READY if dashes > 0 else SHEET_SPENT)
	_sprite.self_modulate = COLOR_TIRED if stamina < climb_tired_threshold else Color.WHITE
