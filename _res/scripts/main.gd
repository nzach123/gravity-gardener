extends Node2D
@onready var player: Player = $Player
@onready var goal: Goal = $Goal





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#goal.player_reached_goal.connect(player.win_level)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
