extends CharacterBody2D

class_name Player

@onready var player_sprite_2d: Sprite2D = $PlayerSprite2D
@onready var player_area_2d: Area2D = $PlayerArea2D
@onready var player_camera_2d: Camera2D = $PlayerCamera2D

const SPEED = 300.0
var jump_force: float = -300.0
var gravity_inverted = false
var custom_gravity: Vector2 = Vector2(0.0, 980.0)


func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	#gravity = get_gravity()
	velocity += custom_gravity * delta
	up_direction = -custom_gravity.normalized()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
	var move_dir = Vector2(direction, 0.0)
	if is_on_floor():
		velocity.y = jump_force
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	flip_sprite(move_dir)
	move_and_slide()
	
func flip_sprite(move_dir: Vector2) -> void:
	if move_dir == Vector2.LEFT:
		player_sprite_2d.flip_h = true
	if move_dir == Vector2.RIGHT:
		player_sprite_2d.flip_h = false

func win_level() -> void:
	print("Win Level")

func set_gravity(vector: Vector2) -> Vector2:
	custom_gravity = vector
	print(custom_gravity)
	return custom_gravity
	


func GZ_body_entered(zone: Node2D) -> void:
	if zone is GravityZone:
		set_gravity(zone.get_gravity_vector())

func GZ_body_exited(zone: Node2D) -> void:
	if zone is GravityZone:
		set_gravity(Vector2(0.0, 980.0))
