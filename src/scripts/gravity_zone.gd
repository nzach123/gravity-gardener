extends Area2D

class_name  GravityZone

@export var zone_gravity_direction: Vector2 = Vector2.DOWN
## Strength as a multiple of the player's derived baseline gravity (GDD R7).
## 1.0 = baseline, 0.5 = low gravity (higher jumps), 2.0 = heavy (lower jumps).
@export var zone_gravity_multiplier: float = 1.0
## Not yet implemented (GDD R8) — overlapping zones resolve last-entered-wins.
@export var zone_priority: int = 0
@onready var arrow_sprite: Sprite2D = $ArrowSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var color_rect: ColorRect = $ColorRect

signal gravity_changed(direction: Vector2, multiplier: float)

## Returns this zone's gravity direction, normalized. Magnitude is the player's
## concern — the zone only declares direction and a relative multiplier (GDD R7).
## Named `zone_`-prefixed to avoid shadowing Area2D.get_gravity_direction().
func get_zone_gravity_direction() -> Vector2:
	return zone_gravity_direction.normalized()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		gravity_changed.emit(get_zone_gravity_direction(), zone_gravity_multiplier)
		
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
	
	
	
