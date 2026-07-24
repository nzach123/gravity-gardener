extends CharacterBody2D

class_name Player

# --- Node References ---
@onready var player_sprite_2d: AnimatedSprite2D = $PlayerAnimatedSprite2D
@onready var player_area_2d: Area2D = $PlayerArea2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- Core Physics & Movement ---
@export var jump_force: float = -100.0
@export var _speed: float = 350.0
@export var _friction: float = 1200.0
@export var _acceleration: float = 1800.0
@export var terminal_velocity: float = 500.0

const ROT_SPEED: float = 12.0

var gravity_inverted: bool = false
var custom_gravity: Vector2 = Vector2(0.0, 980.0)
var player_score: int = 0
var camera: Camera2D
var _target_rotation: float = 0.0

# --- Bounce Physics Configuration ---
## Energy retained after bouncing (0.0 = dead stop, 1.0 = perfect elastic).
@export var bounce_restitution: float = 0.6
## Energy retained on the tangent axis (simulates surface friction/grip).
@export var surface_friction: float = 0.75
## Max angle deviation in radians for "chaos" (surface roughness).
@export var surface_roughness: float = 0.05 
## Minimum speed thresholds required to trigger a bounce.
@export var floor_bounce_threshold: float = 0.25 
@export var wall_bounce_threshold: float = 0.20 

var _is_bouncing: bool = false
var _is_dead: bool = false
var starting_position: Vector2

# --- Signals ---
## Emitted on valid bounce. Connect this to your Camera2D for shake effects.
signal surface_impacted(impact_force: float, is_floor: bool)

func _ready() -> void:
	up_direction = -custom_gravity.normalized()
	camera = get_tree().get_first_node_in_group("MainCamera")
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("slick"):
		_friction = 0.0
		_speed = 500
		print('friciton')
	if event.is_action_released("slick"):
		_friction = 1200.0
		_speed = 350
		print("frictin normal")
		
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	var up_dir: Vector2 = -custom_gravity.normalized()
	var right_dir: Vector2 = Vector2(-up_dir.y, up_dir.x)
	
	up_direction = up_dir
	velocity += custom_gravity * delta
	
	
	var raw_axis:= Input.get_axis("move_left", "move_right")
	var input_axis: float = 0.0
	var world_right: Vector2 = Vector2.RIGHT
	var alignment:float = right_dir.dot(world_right)

	if not is_equal_approx(alignment, 0.0):
		input_axis = raw_axis * sign(alignment)
	else:
		input_axis = raw_axis * -sign(right_dir.y)
	
	var vel_along:float = velocity.dot(right_dir)
	var vel_perp: float = velocity.dot(up_dir)
	
	# Movement dampening
	if input_axis != 0.0:
		vel_along = move_toward(vel_along, input_axis * _speed, _acceleration * delta)
	else:
		vel_along = move_toward(vel_along, 0.0, _friction * delta)
		
	velocity = right_dir * vel_along + up_dir * vel_perp
	
	var pre_slide_along: float = velocity.dot(right_dir) ## Velocity in the horizontal direction
	var pre_slide_perp: float = velocity.dot(up_dir) ##  Velocity in the vertical direction
	var pre_slide_velocity: Vector2 = velocity
	move_and_slide()


	vel_along = velocity.dot(right_dir)
	vel_perp = velocity.dot(up_dir)

	_player_bounce(pre_slide_along, vel_along, pre_slide_perp, vel_perp, up_dir, right_dir, pre_slide_velocity)
	_flip_sprite(up_dir, delta, input_axis,)
	if velocity.x == 0.0 and is_on_floor():
		player_sprite_2d.play("Idle")
	elif velocity.y != 0.0 and is_on_floor() == false:
		player_sprite_2d.play("Falling")
		print("falling")

func _flip_sprite(up_dir: Vector2, delta:float, input_axis: float) -> void:
	var down_dir: Vector2 = -up_dir
	_target_rotation = down_dir.angle() - (PI * 0.5)
	rotation = lerp_angle(rotation, _target_rotation, ROT_SPEED * delta)
	
	if input_axis > 0.0:
		player_sprite_2d.flip_h = false
		player_sprite_2d.play("MoveRight")
	elif input_axis < 0.0:
		player_sprite_2d.flip_h = true
		player_sprite_2d.play("MoveLeft")


func win_level() -> void:
	player_score +=1
 
func set_gravity(vector: Vector2) -> Vector2:
	custom_gravity = vector
	up_direction = -custom_gravity.normalized()
	print("[Player] Gravity changed to: ", custom_gravity)
	return custom_gravity
	
func _player_bounce(pre_slide_along: float, vel_along: float, pre_slide_perp: float, vel_perp:float, up_dir: Vector2, right_dir: Vector2, pre_slide_vel: Vector2) -> void:

	
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var raw_normal: Vector2 = collision.get_normal()

		# Determine surface orientation relative to custom gravity
		var up_dot: float = raw_normal.dot(up_dir)
		var right_dot: float = absf(raw_normal.dot(right_dir))

		var is_floor: bool = up_dot > 0.7
		var is_wall: bool = right_dot > 0.7

		# Calculate speeds relative to custom gravity axes for threshold checks
		var fall_speed: float = absf(pre_slide_vel.dot(up_dir))
		var lateral_speed: float = absf(pre_slide_vel.dot(right_dir))

		var should_bounce: bool = false
		if is_floor and fall_speed >= terminal_velocity * floor_bounce_threshold:
			should_bounce = true
		elif is_wall and lateral_speed >= _speed * wall_bounce_threshold:
			should_bounce = true

		if not should_bounce:
			continue

		# 1. Simulate Surface Roughness (Physical "Chaos")
		var roughness_angle: float = randf_range(-surface_roughness, surface_roughness)
		var perturbed_normal: Vector2 = raw_normal.rotated(roughness_angle)

		# 2. Decompose Pre-Slide Velocity into Normal and Tangent components
		var normal_vel: Vector2 = perturbed_normal * pre_slide_vel.dot(perturbed_normal)
		var tangent_vel: Vector2 = pre_slide_vel - normal_vel

		# 3. Apply Restitution (Bounce) and Friction (Slide)
		var final_normal_vel: Vector2 = -normal_vel * bounce_restitution
		var final_tangent_vel: Vector2 = tangent_vel * surface_friction

		# 4. Recombine into final velocity
		velocity = final_normal_vel + final_tangent_vel

		# 5. Feedback for Juice (Camera Shake, SFX)
		var impact_force: float = normal_vel.length()
		surface_impacted.emit(impact_force, is_floor)


func GZ_body_entered(zone: Node2D) -> void:
	if zone is GravityZone:
		set_gravity(zone.get_gravity_vector())
