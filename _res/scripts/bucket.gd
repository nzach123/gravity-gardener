extends Node
class_name Bucket


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		print("pick up")
		GameManager.carrying_bucket = true
		queue_free()
