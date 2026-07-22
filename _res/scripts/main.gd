extends Node2D
@onready var player: Player = $Player
@onready var goal: Goal = $Goal





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	goal.player_reached_goal.connect(player.win_level)
	goal.player_reached_goal.connect(change_level)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func change_level() -> void:
	get_tree().change_scene_to_file("res://_res/scenes/test_main.tscn")
