extends Node2D
@onready var player: Player = $Player
@onready var invert_zone: Area2D = $InvertZone

signal inverted_gravity(is_inverted: bool)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_invert_zone_body_entered(body: Node2D) -> void:
	var flipped: bool = true
	inverted_gravity.emit(flipped)
	

func _on_invert_zone_body_exited(body: Node2D) -> void:
	var flipped: bool = false
	inverted_gravity.emit(flipped)
