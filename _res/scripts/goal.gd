extends Node2D

class_name Goal

signal player_reached_goal

@onready var goal_animated_sprite_2d: AnimatedSprite2D = $GoalAnimatedSprite2D

@onready var goal_area_2d: Area2D = $GoalArea2D
@export var flip_sprite: bool = false
func _ready() -> void:
	goal_area_2d.body_entered.connect(_on_body_entered)
	if flip_sprite == true:
		goal_animated_sprite_2d.flip_h = true
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.items:
			player_reached_goal.emit()
			queue_free()
