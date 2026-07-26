extends Node2D
class_name MovingPlatform

# --- Movement Configuration ---
@export var duration: float = 3.0
@export var travel_distance: float = 200.0

# Toggle dictates movement axis and dynamically updates the collision shape in the editor
@export var is_horizontal: bool = true:
	set(value):
		is_horizontal = value
		_update_shape_size()

# --- Sizing Configuration ---
# Setters ensure the collision shape resizes live in the editor when tweaked
@export var platform_length_blocks: int = 3:
	set(value):
		platform_length_blocks = value
		_update_shape_size()

@export var block_size: int = 16:
	set(value):
		block_size = value
		_update_shape_size()

# --- Node References ---
# Safely grabs the CollisionShape2D based on the required hierarchy
@onready var collision_shape: CollisionShape2D = $AnimatedBody2D/CollisionShape2D
@onready var sprite_2d: Sprite2D = $AnimatedBody2D/Sprite2D

var sprite_blocks: Array[Sprite2D] = []
# Internal flag to track if we've already duplicated the shape resource for this instance
var _is_shape_unique: bool = false

func _ready() -> void:
	# Ensure this instance has its own unique shape resource before modifying it
	_ensure_unique_shape()
	_update_shape_size()
	_update_visuals()
	_start_movement()

func _ensure_unique_shape() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D and not _is_shape_unique:
		# Duplicate the shape so resizing this platform doesn't affect others sharing the resource
		collision_shape.shape = collision_shape.shape.duplicate()
		_is_shape_unique = true
		
func _update_visuals() -> void:
	for block in sprite_blocks:
		if is_instance_valid(block):
			block.queue_free()
		sprite_blocks.clear()
	var center_offset: float = - (platform_length_blocks - 1.0) / 2.0 * block_size
	
	for i in range(platform_length_blocks):
		var new_sprite = Sprite2D.new()
		new_sprite.texture = sprite_2d.texture
		new_sprite.region_enabled = sprite_2d.region_enabled
		new_sprite.region_rect = sprite_2d.region_rect
		
		var block_position: float = center_offset + (i * block_size)
		if is_horizontal:
			new_sprite.position = Vector2(block_position, 0)
		else:
			new_sprite.position = Vector2(0, block_position)
		
		add_child(new_sprite)
		sprite_blocks.append(new_sprite)
		print(new_sprite.texture)
		
		
	
func _update_shape_size() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		# Calculate dimensions: length is blocks * block_size, thickness is 1 block
		var length_px: float = platform_length_blocks * block_size
		var new_size: Vector2 = Vector2(length_px, block_size) if is_horizontal else Vector2(block_size, length_px)
		collision_shape.shape.size = new_size

func _start_movement() -> void:
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_loops()
	tween.set_parallel(false)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	var half_time: float = duration / 2.0
	var start_pos: Vector2 = global_position
	
	# Calculate directional offset automatically based on the horizontal toggle
	var move_offset: Vector2 = Vector2(travel_distance, 0.0) if is_horizontal else Vector2(0.0, travel_distance)
	var end_pos: Vector2 = start_pos + move_offset
	
	tween.tween_property(self, "global_position", end_pos, half_time)
	tween.tween_property(self, "global_position", start_pos, half_time)
