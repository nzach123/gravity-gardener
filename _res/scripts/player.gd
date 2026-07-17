extends CharacterBody2D

class_name Player

@onready var player_sprite_2d: Sprite2D = $PlayerSprite2D
@onready var player_area_2d: Area2D = $Area2D
@onready var player_camera_2d: Camera2D = $Camera2D


const SPEED = 300.0

var direction: float = 0.0
var gravity: Vector2 = Vector2.ZERO

var gravity_inverted = false

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	gravity = get_gravity()
	velocity += gravity * delta
	print(velocity)
	



	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
	var move_dir = Vector2(direction, 0.0)
	
	
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



	


func _on_main_inverted_gravity(is_inverted: bool) -> void:
	if is_inverted:
		print("inverted")
		gravity_inverted = true
		
	else:
		print("normal")
