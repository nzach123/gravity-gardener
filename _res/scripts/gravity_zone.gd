extends Area2D

class_name  GravityZone

@export var zone_gravity_direction: Vector2 = Vector2.DOWN
@export var zone_gravity_strength: float = 980.0
@export var zone_priority: int = 0

# Gets and returns the gravity vector only.
func get_gravity_vector() -> Vector2:
	return zone_gravity_direction.normalized() * zone_gravity_strength

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.GZ_body_entered(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.GZ_body_exited(self)
