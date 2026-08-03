extends Node2D
class_name Plant
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area_2d: Area2D = $InteractArea2D

@export var item: String = "item"


func _on_interact_body_entered(body: Node2D) -> void:
	if body is Player:
		body.collect(item)
		queue_free()
