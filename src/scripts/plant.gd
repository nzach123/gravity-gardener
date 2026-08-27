extends Node2D
class_name Plant

signal plant_watered

## One COMPLETED pour. `LevelRoot._ready()` connects this to
## `LevelState.consume_bucket()`; the plant itself receives no state object and
## never decides the level is over (`plant_decides_level_outcome` is forbidden).
##
## Declared here ahead of ADR-0009, which will move the emit out of
## `_complete_watering()` and into `receive_pour()` so it fires once per BUCKET
## poured rather than once per PLANT completed. The two agree only while
## `buckets_required == 1`, so that is a behaviour change, not a rename — and it
## is the only change ADR-0009 needs to make here. Same precedent as
## `buckets_required` below.
signal pour_completed

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area_2d: Area2D = $InteractArea2D

var water_progress: float = 0.0
var is_watered: bool = false
@export var water_duration: float = 5.0
## Buckets this plant needs before it is fully watered (watering-system.md R5).
## Declared here ahead of ADR-0009 because V-BUCKET-SUM and V-PLANT-MIN cannot be
## tested against a property no class declares. The behaviour half — buckets_received,
## the intake cap, pour refusal, growth visuals — stays with ADR-0009.
## The range does not clamp a hand-edited .tscn (ADR-0006 T4); V-PLANT-MIN is the
## load-time floor that actually holds.
@export_range(1, 4) var buckets_required: int = 1
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
	pour_completed.emit()
	
	# Update GameManager
	var gm = GameManager
	if gm:
		gm.plants_watered += 1
		if gm.plants_watered >= gm.plants_total:
			gm.goal_unlocked = true
			gm.carrying_bucket = false
	
	# Unlock player
	if player_in_range:
		player_in_range.is_watering = false


func _reset_watering() -> void:
	water_progress = 0.0
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.play("Idle")
	if player_in_range:
		player_in_range.is_watering = false
