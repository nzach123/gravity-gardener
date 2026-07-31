extends Node2D
@export var player: Player
@export var goal: Goal
@export var next_level: PackedScene
@onready var camera_2d: Camera2D = $Camera2D

@export var camera_moving: bool = false

var camera_tween: Tween
func _ready() -> void:
	camera_2d.ignore_rotation = false
	if goal and player:
		goal.player_reached_goal.connect(player.win_level)
		goal.player_reached_goal.connect(change_level)
		
	# Collects all hazards in Group hazards
	var hazards = get_tree().get_nodes_in_group("hazards")
	for hazard in hazards:
		hazard.inc_hazard_dmg.connect(restart_level)
		
	var gravityzone = get_tree().get_nodes_in_group("gravityzone")
	for zone in gravityzone:
		zone.gravity_changed.connect(player.set_gravity)
		zone.gravity_changed.connect(_rotate_camera_to_gravity)
		
			
func _rotate_camera_to_gravity(gravity: Vector2) -> void:
	if camera_moving:
		var target_rotation = Vector2.DOWN.angle_to(gravity)
		camera_tween = create_tween()
		camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		camera_tween.tween_property(camera_2d, "rotation", target_rotation, .6)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if camera_moving:
		camera_2d.global_position = player.global_position

func change_level() -> void:
	get_tree().change_scene_to_packed(next_level)

	
func restart_level() -> void:
	print("level restart called")
	get_tree().call_deferred("reload_current_scene")

func set_camera() -> void:
	camera_2d.global_position = player.global_position 
	
func follow_camera()->void:
	camera_2d.global_position = player.global_position 


func _on_kill_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		restart_level()
