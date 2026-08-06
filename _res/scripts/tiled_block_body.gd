extends Node2D
class_name TiledBlockBody

# -------------------------------------------------------------------------------
# Shared component for building a rectangular multi-block shape with tiled
# sprites and a collision shape. Used by MovingPlatform and Hazard via composition.
# -------------------------------------------------------------------------------

@export var block_count: int = 3:
	set(value):
		block_count = value
		if _initialized:
			update_shape()

@export var block_size: int = 16:
	set(value):
		block_size = value
		if _initialized:
			update_shape()

@export var is_horizontal: bool = true:
	set(value):
		is_horizontal = value
		if _initialized:
			update_shape()

var sprite_blocks: Array[Sprite2D] = []

var _is_shape_unique: bool = false
var _sprite_template: Sprite2D
var _collision_shape: CollisionShape2D
var _parent_node: Node2D
var _initialized: bool = false

# Wire up references and trigger the initial apply. Call once from the parent's
# _ready() after syncing the exported values.
func setup(parent_node: Node2D, sprite_template: Sprite2D, collision_shape: CollisionShape2D) -> void:
	_parent_node = parent_node
	_sprite_template = sprite_template
	_collision_shape = collision_shape
	_initialized = true
	_apply()

func _apply() -> void:
	_ensure_unique_shape()
	update_shape()
	update_visuals()

func _ensure_unique_shape() -> void:
	if _collision_shape and _collision_shape.shape is RectangleShape2D and not _is_shape_unique:
		_collision_shape.shape = _collision_shape.shape.duplicate()
		_is_shape_unique = true

func update_visuals() -> void:
	for block in sprite_blocks:
		if is_instance_valid(block):
			block.queue_free()
	sprite_blocks.clear()

	if not _sprite_template:
		return

	var center_offset: float = - (block_count - 1.0) / 2.0 * block_size

	for i in range(block_count):
		var new_sprite := Sprite2D.new()
		new_sprite.texture = _sprite_template.texture
		new_sprite.region_enabled = _sprite_template.region_enabled
		new_sprite.region_rect = _sprite_template.region_rect

		var block_position: float = center_offset + (i * block_size)
		if is_horizontal:
			new_sprite.position = Vector2(block_position, 0)
		else:
			new_sprite.position = Vector2(0, block_position)

		_parent_node.add_child(new_sprite)
		sprite_blocks.append(new_sprite)
		print(new_sprite.texture)

func update_shape() -> void:
	if _collision_shape and _collision_shape.shape is RectangleShape2D:
		var length_px: float = block_count * block_size
		var new_size: Vector2 = Vector2(length_px, block_size) if is_horizontal else Vector2(block_size, length_px)
		_collision_shape.shape.size = new_size
