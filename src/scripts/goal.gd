extends Node2D

class_name Goal

signal player_reached_goal

@onready var goal_animated_sprite_2d: AnimatedSprite2D = $GoalAnimatedSprite2D
@onready var goal_area_2d: Area2D = $GoalArea2D
@export var flip_sprite: bool = false

var is_unlocked: bool = false

# Injected by LevelRoot._ready() at step (c) (ADR-0002 part 3). Because _ready()
# runs bottom-up, this is still null during THIS node's _ready() — never read it
# there (`state_access_before_bind` is forbidden).
var _level_state: LevelState = null
var _bound: bool = false


## Receives this level's [LevelState] from `LevelRoot._ready()`. Called exactly
## once per level, after every child is ready.
func bind(level_state: LevelState) -> void:
	_level_state = level_state
	_bound = true


## The single read of level unlock state. Refuses to operate before [method bind]
## has run: `push_error()` LOGS but does not pause execution, so the early
## `return` is what actually prevents the null dereference. `assert()` is not
## used — it compiles out of release exports and this guard would silently vanish
## from the shipped build (ADR-0002, A2-02).
func _is_goal_unlocked() -> bool:
	if not _bound:
		push_error("Goal: _is_goal_unlocked() called before bind()")
		return false
	return _level_state.goal_unlocked


func _ready() -> void:
	goal_area_2d.body_entered.connect(_on_body_entered)
	if flip_sprite == true:
		goal_animated_sprite_2d.flip_h = true
	# Start in locked state
	goal_animated_sprite_2d.play("goal_begin")


func _process(_delta: float) -> void:
	if not is_unlocked:
		if _is_goal_unlocked():
			print("unlocked")
			is_unlocked = true
			goal_animated_sprite_2d.play("goal_open")
			#goal_animated_sprite_2d.animation_finished.connect(_on_activation_finished, CONNECT_ONE_SHOT)
			


#func _on_activation_finished() -> void:
	#goal_animated_sprite_2d.play("Idle")


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if _is_goal_unlocked():
			player_reached_goal.emit()
