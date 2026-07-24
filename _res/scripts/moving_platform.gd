extends Node2D
class_name MovingPlatform

@export var duration: float = 3.0
@export var offset: Vector2 = Vector2(200,0.0)
@onready var hazard_moving: Node2D = $"."



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	moving_platorm()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func moving_platorm()-> void:
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_loops()
	tween.set_parallel(false)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	var half_time: float = duration / 2.0
	var start_pos = hazard_moving.global_position
	tween.tween_property(hazard_moving, "position", start_pos + offset, half_time)
	tween.tween_property(hazard_moving, "position", start_pos, half_time)
	
	
	
