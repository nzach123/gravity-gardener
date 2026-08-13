extends Node2D

class_name Goal

signal player_reached_goal

@onready var goal_animated_sprite_2d: AnimatedSprite2D = $GoalAnimatedSprite2D
@onready var goal_area_2d: Area2D = $GoalArea2D
@export var flip_sprite: bool = false

var is_unlocked: bool = false


func _ready() -> void:
	goal_area_2d.body_entered.connect(_on_body_entered)
	if flip_sprite == true:
		goal_animated_sprite_2d.flip_h = true
	# Start in locked state
	goal_animated_sprite_2d.play("goal_begin")


func _process(_delta: float) -> void:
	if not is_unlocked:
		
		var gm = GameManager
		if gm and gm.goal_unlocked:
			print("unlocked")
			is_unlocked = true
			goal_animated_sprite_2d.play("goal_open")
			#goal_animated_sprite_2d.animation_finished.connect(_on_activation_finished, CONNECT_ONE_SHOT)
			


#func _on_activation_finished() -> void:
	#goal_animated_sprite_2d.play("Idle")


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var gm = GameManager
		if gm and gm.goal_unlocked:
			player_reached_goal.emit()
