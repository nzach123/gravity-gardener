extends Node2D
class_name Plant

signal plant_watered

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area_2d: Area2D = $InteractArea2D

var water_progress: float = 0.0
var is_watered: bool = false
@export var water_duration: float = 5.0
var player_in_range: Player = null


func _ready() -> void:
	add_to_group("plants")
	animated_sprite_2d.play("Idle")


func _process(delta: float) -> void:
	if player_in_range != null and not is_watered:
		# Safety: if player died while watering, release the lock
		if player_in_range.player_died:
			_reset_watering()
			player_in_range = null
			return
		
		if Input.is_action_pressed("interact"):
			# Lock player movement
			if GameManager.carrying_bucket:
				player_in_range.is_watering = true
				
				# Advance watering progress
				water_progress += delta
				
				# Drive the filling animation
				animated_sprite_2d.speed_scale = 2.0 / water_duration
				if animated_sprite_2d.animation != "Filling":
					animated_sprite_2d.play("Filling")
				
				# Check if watering is complete
				if water_progress >= water_duration:
					_complete_watering()
					
		
		elif Input.is_action_just_released("interact"):
			# Early release — reset progress
			_reset_watering()


func _on_interact_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = body
		# Don't start playing Filling yet — wait for E press in _process


func _on_interact_body_exited(body: Node2D) -> void:
	if body is Player:
		if is_watered != true:
			_reset_watering()
			player_in_range = null
		else:
			animated_sprite_2d.play("Filled")
			


func _complete_watering() -> void:
	is_watered = true
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.play("Filled")
	plant_watered.emit()
	
	# Update GameManager
	var gm = get_node("/root/GameManager")
	if gm:
		gm.plants_watered += 1
		if gm.plants_watered >= gm.plants_total:
			gm.goal_unlocked = true
	
	# Unlock player
	if player_in_range:
		player_in_range.is_watering = false


func _reset_watering() -> void:
	water_progress = 0.0
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.play("Idle")
	if player_in_range:
		player_in_range.is_watering = false
