extends Node

var player_lives = 5

# Watering mechanic state
var goal_unlocked: bool = false
var plants_watered: int = 0
var plants_total: int = 0

var carrying_bucket = false

func reset_level_state() -> void:
	goal_unlocked = false
	plants_watered = 0
	plants_total = 0
