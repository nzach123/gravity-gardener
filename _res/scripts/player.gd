extends CharacterBody2D

class_name Player



@onready var player_sprite_2d: Sprite2D = $PlayerSprite2D
@onready var player_area_2d: Area2D = $PlayerArea2D

@onready var terminal_velocity: float = 500
@export var jump_force: float = -100.0
@export var _speed = 350.0
@export var _friction: float = 1200.0
@export var _acceleration: float = 1800.0

const ROT_SPEED: float = 12.0


var gravity_inverted = false
var custom_gravity: Vector2 = Vector2(0.0, 980.0)
var player_score: int = 0
var camera: Camera2D
var _target_rotation: float = 0.0

# Bounce Variables
var _is_bouncing: bool = false
var bounce_threshold: float = 0.75
var bounce_restitution: float = 0.25
var chaos_factor: float = 180.0

var _is_dead = false
var starting
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
	
	move_and_slide()
	
	vel_along = velocity.dot(right_dir)
	vel_perp = velocity.dot(up_dir)
	# Bounce Detection
	player_bounce(pre_slide_along, vel_along, pre_slide_perp, vel_perp, up_dir, right_dir)
				
	_flip_sprite(up_dir, delta, input_axis)

func _flip_sprite(up_dir: Vector2, delta:float, input_axis: float) -> void:
	var down_dir: Vector2 = -up_dir
	_target_rotation = down_dir.angle() - (PI * 0.5)
	rotation = lerp_angle(rotation, _target_rotation, ROT_SPEED * delta)
	
	if input_axis > 0.0:
		player_sprite_2d.flip_h = false
	if input_axis < 0.0:
		player_sprite_2d.flip_h = true

func win_level() -> void:
	player_score +=1
 
func set_gravity(vector: Vector2) -> Vector2:
	custom_gravity = vector
	up_direction = -custom_gravity.normalized()
	print("[Player] Gravity changed to: ", custom_gravity)
	return custom_gravity
	
func player_bounce(pre_slide_along: float, vel_along: float, pre_slide_perp: float, vel_perp:float, up_dir: Vector2, right_dir: Vector2) -> void:
	var fall_speed: float = absf(pre_slide_perp) ## Up and Down velocity
	var lateral_speed: float = absf(pre_slide_along) ## Side to side velocity
	
	for i in get_slide_collision_count():
		var normal: Vector2 = get_slide_collision(i).get_normal()

		# --- Floor bounce ---
		if absf(normal.dot(up_dir)) > 0.7 and fall_speed >= terminal_velocity * bounce_threshold:
			var bounced_perp: float = -pre_slide_perp * bounce_restitution
			var speed_ratio: float = clampf(fall_speed / terminal_velocity, 0.0, 1.0)
			var chaos: Vector2 = right_dir * randf_range(-chaos_factor, chaos_factor) * speed_ratio
			velocity = up_dir * bounced_perp + right_dir * vel_along + chaos
			print("Floor Bounce")
			# Emit signal and connect the camera can use intensity 

		# --- Wall bounce ---
		elif absf(normal.dot(right_dir)) > 0.7 and lateral_speed >= _speed * bounce_threshold:
			var bounced_along: float = -pre_slide_along * bounce_restitution
			velocity = right_dir * bounced_along + up_dir * vel_perp
			print("Wall Bounce")


func GZ_body_entered(zone: Node2D) -> void:
	if zone is GravityZone:
		set_gravity(zone.get_gravity_vector())
