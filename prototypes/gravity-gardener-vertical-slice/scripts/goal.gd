# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Behaviour unchanged from the pre-refactor goal.gd — only the source of
# goal_unlocked moves, from GameManager to the injected LevelState (ADR-0002,
# watering-system.md R6). collision_layer = 0, collision_mask = PLAYER (ADR-0004),
# set on the .tscn.
class_name Goal
extends Node2D

signal player_reached_goal

## Placeholder-quality: a plain ColorRect stands in for the locked/open sprite states.
@onready var sprite: ColorRect = $ColorRect
@onready var area: Area2D = $GoalArea2D

var level_state: LevelState

var _is_bound: bool = false
var _is_open: bool = false
var _player_inside: bool = false
var _reached: bool = false


func bind(level_state_ref: LevelState) -> void:
	level_state = level_state_ref
	_is_bound = true


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	sprite.color = Color.DIM_GRAY


## Checked every frame, not just on the entry signal — the win condition must
## fire the instant the goal unlocks even if the player is already standing in
## it (a fresh body_entered event is not guaranteed to follow an unlock).
func _process(_delta: float) -> void:
	if not _is_bound:
		return
	if not _is_open and level_state.goal_unlocked:
		_is_open = true
		sprite.color = Color.GOLD
	if not _reached and _player_inside and level_state.goal_unlocked:
		_reached = true
		player_reached_goal.emit()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
