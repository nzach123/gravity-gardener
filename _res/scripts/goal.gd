extends Node2D

class_name Goal

signal player_reached_goal

@onready var goal_area_2d: Area2D = $GoalArea2D

func _ready() -> void:
	goal_area_2d.body_entered.connect(_on_body_entered)
	
	
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_reached_goal.emit()
		queue_free()
