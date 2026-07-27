extends CharacterBody2D
class_name Player

# --- Configuration ---
@export var max_speed: float = 350.0
@export var crouch_slide_speed: float = 500.0
@export var jump_force: float = 450.0
@export var jump_cut_multiplier: float = 0.4

@export var ground_accel: float = 1800.0
@export var ground_friction: float = 1200.0
@export var crouch_friction: float = 50.0
@export var air_accel: float = 900.0
@export var air_drag: float = 150.0

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

@export var squash_stretch_speed: float = 12.0
@export var scale_jump: Vector2 = Vector2(0.8, 1.2)
@export var scale_land: Vector2 = Vector2(1.3, 0.7)
@export var scale_crouch: Vector2 = Vector2(1.4, 0.5)
@export var scale_run: Vector2 = Vector2(1.1, 0.95)

@export var bounce_restitution: float = 0.5
@export var surface_friction: float = 0.55
@export var surface_roughness: float = 0.00 
@export var sprite_target_size: Vector2 = Vector2(2.0,2.0)
# --- Node References ---
@onready var sprite: AnimatedSprite2D = $PlayerAnimatedSprite2D
@onready var col_shape: CollisionShape2D = $PlayerArea2D/PlayerCollisionShape2D

# --- State ---
var gravity: Vector2 = Vector2(0, 980)
var target_gravity: Vector2 = Vector2(0, 980)

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var land_squash_timer: float = 0.0

var is_crouching: bool = false
var is_jumping: bool = false
var was_on_floor: bool = false

var original_shape_extents: Vector2 = Vector2.ZERO

# --- Lifecycle ---
func _ready() -> void:
	if col_shape.shape is RectangleShape2D:
		original_shape_extents = col_shape.shape.extents
	elif col_shape.shape is CapsuleShape2D:
		original_shape_extents = Vector2(col_shape.shape.radius, col_shape.shape.height)

func _physics_process(delta: float) -> void:
	var up_dir := -gravity.normalized()
	var right_dir := Vector2(-up_dir.y, up_dir.x)
	
	_update_gravity(delta)
	_apply_gravity(delta, up_dir)
	
	_handle_jumping(delta, up_dir)
	_handle_crouching()
	
	_apply_movement(delta, right_dir, up_dir)
	
	var pre_slide_vel := velocity
	move_and_slide()
	
	_handle_bounce(pre_slide_vel, up_dir, right_dir)
	_update_visuals(delta, right_dir)

# --- Core Mechanics ---
func _update_gravity(delta: float) -> void:
	if gravity.is_equal_approx(target_gravity): return
	
	var new_angle := lerp_angle(gravity.angle(), target_gravity.angle(), clampf(8.0 * delta, 0.0, 1.0))
	var new_mag := move_toward(gravity.length(), target_gravity.length(), 25.0 * delta)
	gravity = Vector2.RIGHT.rotated(new_angle) * new_mag
	up_direction = -gravity.normalized()


func _apply_gravity(delta: float, up_dir: Vector2) -> void:
	velocity += gravity * delta
	# Clamp terminal velocity
	var fall_speed := velocity.dot(gravity.normalized())
	if fall_speed > 1500.0:
		velocity -= gravity.normalized() * (fall_speed - 1500.0)

func _handle_jumping(delta: float, up_dir: Vector2) -> void:
	coyote_timer = coyote_time if is_on_floor() else coyote_timer - delta
	jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else jump_buffer_timer - delta

	# Execute jump
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity += up_dir * jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		is_jumping = true
		land_squash_timer = 0.0

	# Variable jump height (cut short if released early)
	var vel_up := velocity.dot(up_dir)
	if Input.is_action_just_released("jump") and vel_up > 0.0:
		velocity -= up_dir * (vel_up * (1.0 - jump_cut_multiplier))
		is_jumping = false

	# Detect landing for squash effect
	if is_on_floor() and not was_on_floor:
		land_squash_timer = 0.15
		is_jumping = false
	was_on_floor = is_on_floor()
	
	if land_squash_timer > 0.0: land_squash_timer -= delta

func _handle_crouching() -> void:
	var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
	if wants_crouch == is_crouching: return

	is_crouching = wants_crouch
	var scale_factor := Vector2(1.2, 0.5) if is_crouching else Vector2.ONE
	
	if col_shape.shape is RectangleShape2D:
		col_shape.shape.extents = original_shape_extents * scale_factor
	elif col_shape.shape is CapsuleShape2D:
		col_shape.shape.height = original_shape_extents.y * scale_factor.y

func _apply_movement(delta: float, right_dir: Vector2, up_dir: Vector2) -> void:
	var raw_input = Input.get_axis("move_left", "move_right")
	var input_axis = raw_input * sign(right_dir.dot(Vector2.RIGHT)) if not is_zero_approx(right_dir.dot(Vector2.RIGHT)) else raw_input * -sign(right_dir.y)

	var current_speed := crouch_slide_speed if is_crouching else max_speed
	var current_accel := ground_accel if is_on_floor() else air_accel
	var current_friction := crouch_friction if is_crouching else (ground_friction if is_on_floor() else air_drag)

	var vel_side := velocity.dot(right_dir)
	if input_axis != 0.0 and not is_crouching:
		vel_side = move_toward(vel_side, input_axis * current_speed, current_accel * delta)
	else:
		vel_side = move_toward(vel_side, 0.0, current_friction * delta)
		
	velocity = right_dir * vel_side + up_dir * velocity.dot(up_dir)

# --- Physics Interactions ---
func _handle_bounce(pre_slide_vel: Vector2, up_dir: Vector2, right_dir: Vector2) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		
		var is_floor := normal.dot(up_dir) > 0.7
		var is_wall := absf(normal.dot(right_dir)) > 0.7
		
		var fall_speed := absf(pre_slide_vel.dot(up_dir))
		var side_speed := absf(pre_slide_vel.dot(right_dir))
		
		if not (is_floor and fall_speed > 375.0) and not (is_wall and side_speed > 70.0):
			continue

		# Add surface roughness (chaos)
		var perturbed_normal := normal.rotated(randf_range(-surface_roughness, surface_roughness))
		if perturbed_normal.dot(normal) < 0.2: perturbed_normal = normal

		# Decompose, apply restitution/friction, and reconstruct
		var normal_vel := perturbed_normal * pre_slide_vel.dot(perturbed_normal)
		var tangent_vel := pre_slide_vel - normal_vel
		
		velocity = (-normal_vel * bounce_restitution) + (tangent_vel * surface_friction) + (normal * 15.0)
		break

# --- Visuals ---
func _update_visuals(delta: float, right_dir: Vector2) -> void:
	# Rotation
	var target_rot := gravity.normalized().angle() - (PI * 0.5)
	rotation = lerp_angle(rotation, target_rot, 12.0 * delta)
	
	# Flipping
	var input_axis := Input.get_axis("move_left", "move_right")
	if input_axis != 0.0 :
		if right_dir.x < 0.0:
			sprite.flip_h = input_axis > 0.0
		else:
			sprite.flip_h = input_axis < 0.0
		
	
	# Squash & Stretch
	var target_scale := Vector2.ONE
	if land_squash_timer > 0.0: 
		target_scale = scale_land
	elif is_crouching: 
		target_scale = scale_crouch
	elif not is_on_floor(): 
		target_scale = scale_jump
	elif absf(velocity.dot(right_dir)) > max_speed * 0.8: 
		target_scale = scale_run
	
	sprite.scale = sprite.scale.lerp(sprite.scale, squash_stretch_speed * delta)

	# Animation State
	if is_crouching: sprite.play("Crouch")
	elif not is_on_floor(): sprite.play("Falling" if velocity.dot(-gravity.normalized()) > 0 else "Jump")
	elif is_zero_approx(velocity.dot(right_dir)): sprite.play("Idle")
	else: sprite.play("MoveRight")

# --- External API ---
func set_gravity(vector: Vector2) -> void:
	target_gravity = vector
	

func win_level() -> void:
	#player_score += 1
	pass
func GZ_body_entered(zone: Node2D) -> void:
	if zone is GravityZone:
		set_gravity(zone.get_gravity_vector())
