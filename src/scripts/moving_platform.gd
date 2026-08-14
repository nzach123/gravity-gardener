extends Node2D
class_name MovingPlatform

@export var duration: float = 3.0
@export var travel_distance: float = 200.0
@export var is_direction_vertical: bool = true
@export var is_horizontal: bool = true:
	set(value):
		is_horizontal = value
		if tiled_body:
			tiled_body.is_horizontal = value

@export var platform_length_blocks: int = 3:
	set(value):
		platform_length_blocks = value
		if tiled_body:
			tiled_body.block_count = value

@export var block_size: int = 16:
	set(value):
		block_size = value
		if tiled_body:
			tiled_body.block_size = value

@onready var tiled_body: TiledBlockBody = $TiledBlockBody

func _ready() -> void:
	# Sync exported values to component, then initialize it
	tiled_body.block_count = platform_length_blocks
	tiled_body.block_size = block_size
	tiled_body.is_horizontal = is_horizontal
	tiled_body.setup(self, $AnimatedBody2D/Sprite2D, $AnimatedBody2D/CollisionShape2D)
	_start_movement()

func _start_movement() -> void:
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_loops()
	tween.set_parallel(false)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	var half_time: float = duration / 2.0
	var start_pos: Vector2 = global_position
	
	var move_offset: Vector2 = Vector2(0.0, travel_distance) if is_direction_vertical else Vector2(travel_distance, 0.0)
	var end_pos: Vector2 = start_pos + move_offset
	
	tween.tween_property(self, "global_position", end_pos, half_time)
	tween.tween_property(self, "global_position", start_pos, half_time)
