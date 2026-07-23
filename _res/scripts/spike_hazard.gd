extends Area2D

class_name Hazard

signal inc_hazard_dmg

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		inc_hazard_dmg.emit()
		print("hazard dmg emitted")
