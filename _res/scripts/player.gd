extends CharacterBody2D

class_name Player

@onready var player_sprite_2d: Sprite2D = $PlayerSprite2D
@onready var player_area_2d: Area2D = $PlayerArea2D

@export var jump_force: float = -100.0

const SPEED = 300.0
const FRICTION: float = 1800.0
const ACCELERATION: float = 1800.0
const ROT_SPEED: float = 12.0

var gravity_inverted = false
var custom_gravity: Vector2 = Vector2(0.0, 980.0)

var camera: Camera2D
var _target_rotation: float = 0.0

func _ready() -> void:
	up_direction = -custom_gravity.normalized()
	var camera = get_tree().get_first_node_in_group("MainCamera")
	print(camera)
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	var up_dir: Vector2 = -custom_gravity.normalized()
	var right_dir: Vector2 = Vector2(-up_dir.y, up_dir.x)
	
	up_direction = up_dir
	
	velocity += custom_gravity * delta
	
	
	var raw_axis:= Input.get_axis("move_left", "move_right")
	var world_right: Vector2 = Vector2.RIGHT
	var alignment:float = right_dir.dot(world_right)
	var input_axis: float = 0.0
	
	if not is_equal_approx(alignment, 0.0):
		input_axis = raw_axis * sign(alignment)
	else:
		input_axis = raw_axis * -sign(right_dir.y)
	
	var vel_along:float = velocity.dot(right_dir)
	var vel_perp: float = velocity.dot(up_dir)

	if input_axis != 0.0:
		vel_along = move_toward(vel_along, input_axis * SPEED, ACCELERATION * delta)
	else:
		vel_along = move_toward(vel_along, 0.0, FRICTION * delta)
		
	velocity = right_dir * vel_along + up_dir * vel_perp
	move_and_slide()
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
	print("Win Level")

func set_gravity(vector: Vector2) -> Vector2:
	custom_gravity = vector
	up_direction = -custom_gravity.normalized()
	print(up_direction)
	print("[Player] Gravity changed to: ", custom_gravity)
	return custom_gravity


func GZ_body_entered(zone: Node2D) -> void:
	if zone is GravityZone:
		set_gravity(zone.get_gravity_vector())
