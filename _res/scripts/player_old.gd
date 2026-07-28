extends CharacterBody2D


# --- Configuration: SMB-Tuned Physics ---
@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0   # Near-instant acceleration
@export var ground_friction: float = 4000.0 # Near-instant stopping
@export var air_accel: float = 4000.0      # Incredibly strong air control
@export var air_drag: float = 0.0          # Zero float/delay in air

@export var gravity_mag: float = 3200.0    # Heavy, snappy gravity
@export var terminal_velocity: float = 2500.0
@export var jump_force: float = 850.0
@export var jump_cut_multiplier: float = 0.4

@export var wall_jump_h_force: float = 450.0
@export var wall_jump_v_force: float = 800.0
@export var wall_jump_cooldown: float = 0.15

@export var slide_friction: float = 1500.0
@export var min_slide_speed: float = 150.0

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15
@export var corner_correction_distance: float = 8.0

@export var squash_stretch_speed: float = 15.0
@export var scale_jump: Vector2 = Vector2(0.8, 1.2)
@export var scale_land: Vector2 = Vector2(1.3, 0.7)
@export var scale_crouch: Vector2 = Vector2(1.4, 0.5)
@export var scale_run: Vector2 = Vector2(1.1, 0.95)

# --- Node References ---
@onready var sprite: AnimatedSprite2D = $PlayerAnimatedSprite2D
@onready var col_shape: CollisionShape2D = $PlayerArea2D/PlayerCollisionShape2D

# --- State ---
var gravity: Vector2 = Vector2(0, gravity_mag)
var target_gravity: Vector2 = Vector2(0, gravity_mag)

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_timer: float = 0.0
var land_squash_timer: float = 0.0

var is_crouching: bool = false
var is_sliding: bool = false
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
	
	wall_jump_timer = max(0.0, wall_jump_timer - delta)
	
	_update_gravity(delta)
	_apply_gravity(delta, up_dir)
	
	_handle_wall_jump(up_dir)
	_handle_jumping(delta, up_dir)
	#_handle_sliding(right_dir)
	#_handle_crouching()
	
	_apply_movement(delta, right_dir, up_dir)
	
	move_and_slide()
	
	_handle_corner_correction(up_dir)
	_update_visuals(delta, right_dir, up_dir)

# --- Core Mechanics ---
func _update_gravity(delta: float) -> void:
	if gravity.is_equal_approx(target_gravity): return
	var new_angle := lerp_angle(gravity.angle(), target_gravity.angle(), clampf(32.0 * delta, 0.0, 1.0))
	var new_mag := move_toward(gravity.length(), target_gravity.length(), 25.0 * delta)
	gravity = Vector2.RIGHT.rotated(new_angle) * new_mag
	up_direction = -gravity.normalized()

func _apply_gravity(delta: float, up_dir: Vector2) -> void:
	if not is_on_floor():
		velocity += gravity * delta
		var fall_speed := velocity.dot(gravity.normalized())
		if fall_speed > terminal_velocity:
			velocity -= gravity.normalized() * (fall_speed - terminal_velocity)

func _handle_wall_jump(up_dir: Vector2) -> void:
	if is_on_wall() and not is_on_floor() and wall_jump_timer <= 0.0:
		if Input.is_action_just_pressed("jump"):
			var wall_normal := get_wall_normal()
			# Instant velocity override (No wall sliding)
			velocity = wall_normal * wall_jump_h_force + up_dir * wall_jump_v_force
			wall_jump_timer = wall_jump_cooldown
			jump_buffer_timer = 0.0
			is_jumping = true

func _handle_jumping(delta: float, up_dir: Vector2) -> void:
	coyote_timer = coyote_time if is_on_floor() else coyote_timer - delta
	jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else jump_buffer_timer - delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity += up_dir * jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		is_jumping = true
		land_squash_timer = 0.0

	var vel_up := velocity.dot(up_dir)
	if Input.is_action_just_released("jump") and vel_up > 0.0:
		velocity -= up_dir * (vel_up * (1.0 - jump_cut_multiplier))
		is_jumping = false

	if is_on_floor() and not was_on_floor:
		land_squash_timer = 0.15
		is_jumping = false
	was_on_floor = is_on_floor()
	
	if land_squash_timer > 0.0: land_squash_timer -= delta

func _handle_sliding(right_dir: Vector2) -> void:
	if is_on_floor() and Input.is_action_pressed("crouch"):
		if not is_sliding and abs(velocity.dot(right_dir)) > min_slide_speed:
			is_sliding = true

	if is_sliding:
		if not is_on_floor() or not Input.is_action_pressed("crouch") or abs(velocity.dot(right_dir)) < min_slide_speed:
			is_sliding = false

func _handle_crouching() -> void:
	var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor() and not is_sliding
	if wants_crouch == is_crouching: return

	is_crouching = wants_crouch
	var scale_factor := Vector2(1.2, 0.5) if is_crouching else Vector2.ONE
	
	if col_shape.shape is RectangleShape2D:
		col_shape.shape.extents = original_shape_extents * scale_factor
	elif col_shape.shape is CapsuleShape2D:
		col_shape.shape.height = original_shape_extents.y * scale_factor.y

func _apply_movement(delta: float, right_dir: Vector2, up_dir: Vector2) -> void:
	var raw_input := Input.get_axis("move_left", "move_right")
	var input_axis = raw_input * sign(right_dir.dot(Vector2.RIGHT)) if not is_zero_approx(right_dir.dot(Vector2.RIGHT)) else raw_input * -sign(right_dir.y)

	var vel_side := velocity.dot(right_dir)
	
	if is_sliding:
		# Momentum decay during slide
		vel_side = move_toward(vel_side, 0.0, slide_friction * delta)
	else:
		var target_speed = input_axis * max_speed
		var accel := ground_accel if is_on_floor() else air_accel
		
		vel_side = move_toward(vel_side, target_speed, accel * delta)
		
		# Instant stop when no input on ground
		if input_axis == 0.0 and is_on_floor():
			vel_side = move_toward(vel_side, 0.0, ground_friction * delta)
		
	velocity = right_dir * vel_side + up_dir * velocity.dot(up_dir)

# --- Physics Interactions ---
func _handle_corner_correction(up_dir: Vector2) -> void:
	# Nudges player up if they hit a low wall (ledge tolerance)
	if is_on_wall() and not is_on_floor() and wall_jump_timer <= 0.0:
		var wall_normal := get_wall_normal()
		var space_state := get_world_2d().direct_space_state
		
		var origin := global_position + wall_normal * (original_shape_extents.x + 2.0)
		origin -= up_dir * (original_shape_extents.y * 0.8)
		var target := origin - up_dir * corner_correction_distance

		var query := PhysicsRayQueryParameters2D.create(origin, target)
		var result := space_state.intersect_ray(query)

		if result and result.normal.dot(up_dir) > 0.7:
			global_position -= up_dir * result.position.distance_to(origin)
			global_position -= up_dir * 1.0 # Tiny offset to ensure floor detection

# --- Visuals ---
func _update_visuals(delta: float, right_dir: Vector2, up_dir: Vector2) -> void:
	var target_rot := gravity.normalized().angle() - (PI * 0.5)
	rotation = lerp_angle(rotation, target_rot, 12.0 * delta)
	
	var input_axis := Input.get_axis("move_left", "move_right")
	if input_axis != 0.0:
		sprite.flip_h = (input_axis > 0.0) if right_dir.x < 0.0 else (input_axis < 0.0)
	
	var target_scale := Vector2.ONE
	if land_squash_timer > 0.0: 
		target_scale = scale_land
	elif is_sliding or is_crouching: 
		target_scale = scale_crouch
	elif not is_on_floor(): 
		target_scale = scale_jump
	elif absf(velocity.dot(right_dir)) > max_speed * 0.8: 
		target_scale = scale_run
	
	sprite.scale = sprite.scale.lerp(sprite.scale, squash_stretch_speed * delta)

	if is_sliding: 
		sprite.play("Slide")
	elif is_crouching: 
		sprite.play("Crouch")
	elif not is_on_floor(): 
		sprite.play("Falling" 
		if velocity.dot(-up_dir) > 0 else "Jump")
	elif is_zero_approx(velocity.dot(right_dir)): 
		sprite.play("Idle")
	else: 
		sprite.play("Run")

# --- External API ---
func set_gravity(vector: Vector2) -> void:
	target_gravity = vector

func win_level() -> void:
	pass

func GZ_body_entered(zone: Node2D) -> void:
	if zone is GravityZone:
		set_gravity(zone.get_gravity_vector())
