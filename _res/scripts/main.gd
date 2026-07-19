extends Node2D
@onready var player: Player = $Player
@onready var invert_zone: Area2D = $InvertZone



@export var flip_speed:float = 980.0
var new_velocity: float = 0.0
var is_flipped = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func flip_gravity() -> void:
	is_flipped = !is_flipped
	var target_y = flip_speed if is_flipped else -flip_speed
	player.velocity.y = 0.0


func _on_invert_zone_body_entered(body: Node2D) -> void:
	is_flipped = true
	flip_gravity()
	print(flip_speed)
	print(player.up_direction)
	print("inverted")
	
func _on_invert_zone_body_exited(body: Node2D) -> void:
	flip_speed = 980.0
	player.custom_gravity = Vector2(0.0, flip_speed)
	print(flip_speed)
	print(player.up_direction)
	print("normal")
