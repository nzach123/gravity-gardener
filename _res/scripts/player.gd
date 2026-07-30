extends CharacterBody2D
class_name Player

# ---------------------------------------------------------------
# MOVEMENT
# ---------------------------------------------------------------
@export_group("Movement")
@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0
@export var ground_friction: float = 4000.0
@export var air_accel: float = 4000.0

# ---------------------------------------------------------------
# GRAVITY
# ---------------------------------------------------------------
@export_group("Gravity")
@export var gravity_mag: float = 3200.0
@export var terminal_velocity: float = 2500.0

# ---------------------------------------------------------------
# JUMPING
# ---------------------------------------------------------------
@export_group("Jumping")
@export var jump_force: float = 850.0
@export var jump_cut_multiplier: float = 0.4
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

# ---------------------------------------------------------------
# WALL JUMP
# ---------------------------------------------------------------
@export_group("Wall Jump")
@export var wall_jump_h_force: float = 450.0
@export var wall_jump_v_force: float = 800.0
@export var wall_jump_cooldown: float = 0.15

# ---------------------------------------------------------------
# SQUASH & STRETCH
# ---------------------------------------------------------------
@export_group("Squash and Stretch")
@export var squash_stretch_speed: float = 15.0
@export var scale_base: Vector2 = Vector2(2.0, 2.0)
@export var scale_jump: Vector2 = Vector2(1.6, 2.4)
@export var scale_land: Vector2 = Vector2(2.6, 1.4)
@export var scale_run: Vector2 = Vector2(2.2, 1.9)

# ---------------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------------
@onready var sprite: AnimatedSprite2D = $PlayerAnimatedSprite2D
@onready var col_shape: CollisionShape2D = $PlayerArea2D/PlayerCollisionShape2D

# ---------------------------------------------------------------
# RUNTIME STATE  (not exported — managed internally)
# ---------------------------------------------------------------
var gravity: Vector2 = Vector2.ZERO        # current gravity, may rotate via GravityZone
var target_gravity: Vector2 = Vector2.ZERO # lerp destination
var right_dir: Vector2
var up_dir: Vector2
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_timer: float = 0.0
var land_squash_timer: float = 0.0

var is_jumping: bool = false
var was_on_floor: bool = false

# ---------------------------------------------------------------
# READY
# ---------------------------------------------------------------
func _ready() -> void:
	gravity = Vector2(0.0, gravity_mag)
	target_gravity = Vector2(0.0, gravity_mag)
	scale_base = sprite.scale
	var gravityzone = get_tree().get_nodes_in_group("gravityzone")

# ---------------------------------------------------------------
# PHYSICS LOOP
# ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	up_dir = -gravity.normalized()
	right_dir = Vector2(-up_dir.y, up_dir.x)

	wall_jump_timer = maxf(0.0, wall_jump_timer - delta)
	var input_axis: float = Input.get_axis("move_left", "move_right")
	_update_gravity(delta)
	_apply_gravity(delta)
	_handle_wall_jump(up_dir)
	_handle_jumping(delta, up_dir)
	_apply_movement(delta, right_dir, up_dir, input_axis)

	move_and_slide()

	_update_visuals(delta, right_dir, up_dir, input_axis)

# ---------------------------------------------------------------
# GRAVITY
# ---------------------------------------------------------------
func _update_gravity(delta: float) -> void:
	# Smoothly rotates gravity toward the target set by a GravityZone.
	if gravity.is_equal_approx(target_gravity):
		return
	var new_angle := lerp_angle(gravity.angle(), target_gravity.angle(), clampf(32.0 * delta, 0.0, 1.0))
	var new_mag := move_toward(gravity.length(), target_gravity.length(), 25.0 * delta)
	gravity = Vector2.RIGHT.rotated(new_angle) * new_mag
	up_direction = -gravity.normalized()
	return

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity += gravity * delta
	# Clamp to terminal velocity along the fall axis.
	var fall_speed := velocity.dot(gravity.normalized())
	if fall_speed > terminal_velocity:
		velocity -= gravity.normalized() * (fall_speed - terminal_velocity)
	
# ---------------------------------------------------------------
# WALL JUMP
# ---------------------------------------------------------------
func _handle_wall_jump(up_dir: Vector2) -> void:
	if is_on_wall() and not is_on_floor() and wall_jump_timer <= 0.0:
		if Input.is_action_just_pressed("jump"):
			velocity = get_wall_normal() * wall_jump_h_force + up_dir * wall_jump_v_force
			wall_jump_timer = wall_jump_cooldown
			jump_buffer_timer = 0.0
			is_jumping = true

# ---------------------------------------------------------------
# JUMPING  (coyote time + jump buffer)
# ---------------------------------------------------------------
func _handle_jumping(delta: float, up_dir: Vector2) -> void:
	# Coyote time: keep the ability to jump briefly after walking off a ledge.
	coyote_timer = coyote_time if is_on_floor() else coyote_timer - delta
	jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else jump_buffer_timer - delta

	# Consume the buffer when coyote window is open.
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity += up_dir * jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		is_jumping = true
		land_squash_timer = 0.0

	# Variable jump height: cutting the button early reduces upward velocity.
	var vel_up := velocity.dot(up_dir)
	if Input.is_action_just_released("jump") and vel_up > 0.0:
		velocity -= up_dir * (vel_up * (1.0 - jump_cut_multiplier))
		is_jumping = false

	# Landing detection.
	if is_on_floor() and not was_on_floor:
		land_squash_timer = 0.15
		is_jumping = false
	was_on_floor = is_on_floor()

	if land_squash_timer > 0.0:
		land_squash_timer -= delta

# ---------------------------------------------------------------
# HORIZONTAL MOVEMENT
# ---------------------------------------------------------------
func _apply_movement(delta: float, right_dir: Vector2, up_dir: Vector2, _input_axis: float) -> void:
	# Map raw left/right input to the current right_dir axis.
	var raw_input := _input_axis
	var input_axis: float
	if not is_zero_approx(right_dir.dot(Vector2.RIGHT)):
		input_axis = raw_input * sign(right_dir.dot(Vector2.RIGHT))
	else:
		input_axis = raw_input * -sign(right_dir.y)

	var vel_side := velocity.dot(right_dir)
	var target_speed := input_axis * max_speed
	var accel := ground_accel if is_on_floor() else air_accel

	vel_side = move_toward(vel_side, target_speed, accel * delta)

	# Snap to stop when there is no input on the ground.
	if input_axis == 0.0 and is_on_floor():
		vel_side = move_toward(vel_side, 0.0, ground_friction * delta)

	# Recompose velocity: preserve the vertical component, replace horizontal.
	velocity = right_dir * vel_side + up_dir * velocity.dot(up_dir)

# ---------------------------------------------------------------
# VISUALS
# ---------------------------------------------------------------
func _update_visuals(delta: float, right_dir: Vector2, up_dir: Vector2, _input_axis: float) -> void:
	# Rotate sprite to match current gravity direction.
	var target_rot := gravity.normalized().angle() - (PI * 0.5)
	rotation = lerp_angle(rotation, target_rot, 16.0 * delta)

	# Flip sprite to face movement direction.
	var input_axis := _input_axis
	if input_axis != 0.0:
		sprite.flip_h = (input_axis > 0.0) if right_dir.x < 0.0 else (input_axis < 0.0)
	
	# Pick target scale for squash & stretch.
	var target_scale := scale_base
	if land_squash_timer > 0.0:
		target_scale = scale_land
	elif not is_on_floor():
		target_scale = scale_jump
	elif absf(velocity.dot(right_dir)) > max_speed * 0.8:
		target_scale = scale_run

	sprite.scale = sprite.scale.lerp(target_scale, squash_stretch_speed * delta)

	# Animations.
	if not is_on_floor():
		sprite.play("Falling" if velocity.dot(-up_dir) > 0 else "Jump")
	elif is_zero_approx(velocity.dot(right_dir)):
		sprite.play("Idle")
	else:
		sprite.play("Run")

# ---------------------------------------------------------------
# EXTERNAL API
# ---------------------------------------------------------------
func set_gravity(new_vector: Vector2) -> void:
	target_gravity = new_vector
	

func win_level() -> void:
	pass

#func GZ_body_entered(zone: Node2D) -> void:
	#if zone is GravityZone:
		#set_gravity(zone.get_gravity_vector())
