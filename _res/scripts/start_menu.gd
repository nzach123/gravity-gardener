extends Control

@export var start_level: PackedScene
func _on_button_pressed() -> void:
	get_tree().change_scene_to_packed(start_level)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
