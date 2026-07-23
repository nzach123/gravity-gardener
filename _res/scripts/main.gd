extends Node2D
@export var player: Player
@export var goal: Goal
@export var next_level: PackedScene


func _ready() -> void:
	if goal and player:
		goal.player_reached_goal.connect(player.win_level)
		goal.player_reached_goal.connect(change_level)
		
	# Collects all hazards in Group hazards
	var hazards = get_tree().get_nodes_in_group("hazards")
	for hazard in hazards:
		hazard.inc_hazard_dmg.connect(restart_level)

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func change_level() -> void:
	get_tree().change_scene_to_packed(next_level)

	
func restart_level() -> void:
	print("level restart called")
	get_tree().call_deferred("reload_current_scene")

	


func _on_kill_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		restart_level()
