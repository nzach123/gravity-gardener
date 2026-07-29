extends Area2D

class_name Hazard

signal inc_hazard_dmg

@export var hazard_length_blocks: int = 3:
	set(value):
		hazard_length_blocks = value
		_update_shape_size()

@export var block_size: int = 17:
	set(value):
		block_size = value
		_update_shape_size()
	
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var spike_hazard: Hazard = $"."

var sprite_blocks: Array[Sprite2D] = []
var _is_shape_unique: bool = false

func _ready() -> void:
	sprite_2d.hide()
	_ensure_unique_shape()
	_update_shape_size()
	_update_visuals()
	var target_position := spike_hazard.global_position
	target_position.x += (collision_shape.shape.size.x / 2.0 - block_size)
	spike_hazard.global_position.x = target_position.x
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		inc_hazard_dmg.emit()
		print("hazard dmg emitted")
		
func _update_shape_size() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var length_px: float = hazard_length_blocks * block_size
		var new_size: Vector2 = Vector2(length_px, block_size) 
		collision_shape.shape.size = new_size
		
func _ensure_unique_shape() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D and not _is_shape_unique:
		collision_shape.shape = collision_shape.shape.duplicate()
		_is_shape_unique = true
		
func _update_visuals() -> void:
	for block in sprite_blocks:
		if is_instance_valid(block):
			block.queue_free()
	sprite_blocks.clear()
	var center_offset: float = - (hazard_length_blocks - 1.0) / 2.0 * block_size
	
	for i in range(hazard_length_blocks):
		var new_sprite = Sprite2D.new()
		new_sprite.texture = sprite_2d.texture
		new_sprite.region_enabled = sprite_2d.region_enabled
		new_sprite.region_rect = sprite_2d.region_rect
		
		var block_position: float = center_offset + (i * block_size)
		new_sprite.position = Vector2(block_position, 0)
		
		add_child(new_sprite)
		sprite_blocks.append(new_sprite)
		print(new_sprite.texture)
	
