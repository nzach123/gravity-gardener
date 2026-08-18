# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
class_name PlayerJumpComponent
extends Node

@export var min_jump_velocity: float = 100.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

var jump_velocity: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jumping: bool = false
var was_on_floor: bool = false

signal jumped
signal landed


func set_jump_velocity(v: float) -> void:
	jump_velocity = v


func update(delta: float, velocity: Vector2, is_on_floor: bool, up_dir: Vector2, right_dir: Vector2) -> Vector2:
	coyote_timer = coyote_time if is_on_floor else coyote_timer - delta
	jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else jump_buffer_timer - delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		var vel_side: float = velocity.dot(right_dir)
		velocity = right_dir * vel_side + up_dir * jump_velocity
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		is_jumping = true
		jumped.emit()

	var vel_up: float = velocity.dot(up_dir)
	if Input.is_action_just_released("jump") and vel_up > 0.0:
		if vel_up > min_jump_velocity:
			velocity -= up_dir * (vel_up - min_jump_velocity)
		is_jumping = false

	if is_on_floor and not was_on_floor:
		is_jumping = false
		landed.emit()

	was_on_floor = is_on_floor
	return velocity
