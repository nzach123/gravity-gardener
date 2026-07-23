extends Area2D

class_name  GravityZone

@export var zone_gravity_direction: Vector2 = Vector2.DOWN
@export var zone_gravity_strength: float = 980.0
@export var zone_priority: int = 0
@onready var arrow_sprite: Sprite2D = $ArrowSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# Gets and returns the gravity vector only.
func get_gravity_vector() -> Vector2:
	return zone_gravity_direction.normalized() * zone_gravity_strength

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.GZ_body_entered(self)
		
func _ready() -> void:
	if zone_gravity_direction == Vector2.DOWN:
		arrow_sprite.rotate(deg_to_rad(180))
	elif zone_gravity_direction == Vector2.RIGHT:
		arrow_sprite.rotate(deg_to_rad(90.0))
	elif zone_gravity_direction == Vector2.UP:
		arrow_sprite.rotate(deg_to_rad(0.0))
	elif zone_gravity_direction == Vector2.LEFT:
		arrow_sprite.rotate(deg_to_rad(-90.0))
		
func snap_to_collision_center() -> void:
	if not is_instance_valid(collision_shape_2d):
		return
	var global_center: Vector2 = collision_shape_2d.global_position
	arrow_sprite.global_position = global_center
