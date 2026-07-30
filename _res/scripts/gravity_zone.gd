extends Area2D

class_name  GravityZone

@export var zone_gravity_direction: Vector2 = Vector2.DOWN
@export var zone_gravity_strength: float = 980.0
@export var zone_priority: int = 0
@onready var arrow_sprite: Sprite2D = $ArrowSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var color_rect: ColorRect = $ColorRect

signal gravity_changed(new_vector: Vector2)

# Gets and returns the gravity vector only.
func get_gravity_vector() -> Vector2:
	return zone_gravity_direction.normalized() * zone_gravity_strength

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		gravity_changed.emit(get_gravity_vector())
		
func _ready() -> void:
	arrow_sprite.rotation = zone_gravity_direction.angle() - Vector2.UP.angle()+ deg_to_rad(-90)
	color_rect_to_collision_shape()
	
func snap_to_collision_center() -> void:
	if not is_instance_valid(collision_shape_2d):
		return
	var global_center: Vector2 = collision_shape_2d.global_position
	arrow_sprite.global_position = global_center
	color_rect.global_position = global_center

func color_rect_to_collision_shape() -> void:
	var collider_shape:= collision_shape_2d.shape.get_rect()
	color_rect.size = collider_shape.size
	color_rect.position = collider_shape.position
	color_rect.offset_transform_position = collision_shape_2d.position
	
	
	
