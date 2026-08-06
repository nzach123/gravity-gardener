extends Area2D

class_name Hazard

signal inc_hazard_dmg

@export var hazard_length_blocks: int = 3:
	set(value):
		hazard_length_blocks = value
		if tiled_body:
			tiled_body.block_count = value

@export var block_size: int = 17:
	set(value):
		block_size = value
		if tiled_body:
			tiled_body.block_size = value

@onready var tiled_body: TiledBlockBody = $TiledBlockBody
@onready var spike_hazard: Hazard = $"."

func _ready() -> void:
	# Sync exported values to component, then initialize it
	tiled_body.block_count = hazard_length_blocks
	tiled_body.block_size = block_size
	tiled_body.is_horizontal = true  # Hazard only supports horizontal orientation
	tiled_body.setup(self, $Sprite2D, $CollisionShape2D)

	# Hide the template sprite as in original implementation
	$Sprite2D.hide()

	# Adjust position as in original implementation
	var target_position := spike_hazard.global_position
	target_position.x += ($CollisionShape2D.shape.size.x / 2.0 - block_size)
	spike_hazard.global_position.x = target_position.x

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.player_died = true
		inc_hazard_dmg.emit()
		print("hazard dmg emitted")
	
