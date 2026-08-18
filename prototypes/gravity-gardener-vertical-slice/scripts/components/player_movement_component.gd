# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
class_name PlayerMovementComponent
extends Node

@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0
@export var ground_friction: float = 4000.0
@export var air_accel: float = 4000.0


## Applies lateral acceleration and friction. [param input_axis] already carries the
## watering-system.md R2 carry-speed multiplier baked into [param max_speed_now] by
## the caller (Player), which reads it from LevelState via carrying_bucket.
func apply(
	delta: float,
	velocity: Vector2,
	is_on_floor: bool,
	right_dir: Vector2,
	up_dir: Vector2,
	input_axis: float,
	max_speed_now: float
) -> Vector2:
	var vel_side: float = velocity.dot(right_dir)
	var target_speed: float = input_axis * max_speed_now
	var accel: float = ground_accel if is_on_floor else air_accel

	vel_side = move_toward(vel_side, target_speed, accel * delta)

	if input_axis == 0.0 and is_on_floor:
		vel_side = move_toward(vel_side, 0.0, ground_friction * delta)

	return right_dir * vel_side + up_dir * velocity.dot(up_dir)
