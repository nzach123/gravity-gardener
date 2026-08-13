class_name PlayerMovementComponent
extends Node

# ---------------------------------------------------------------
# EXPORTS (forwarded from Player facade)
# ---------------------------------------------------------------
@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0
@export var ground_friction: float = 4000.0
@export var air_accel: float = 4000.0

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------
## Apply lateral acceleration, friction, and camera-aware axis mapping.
## Returns modified velocity.
func apply(
	delta: float,
	velocity: Vector2,
	is_on_floor: bool,
	right_dir: Vector2,
	up_dir: Vector2,
	input_axis: float,
	camera_rotation_enabled: bool
) -> Vector2:
	# Invert axis when gravity is flipped and camera rotation is off.
	if not camera_rotation_enabled:
		if not is_zero_approx(right_dir.dot(Vector2.RIGHT)):
			input_axis = input_axis * sign(right_dir.dot(Vector2.RIGHT))
		else:
			input_axis = input_axis * -sign(right_dir.y)

	var vel_side := velocity.dot(right_dir)
	var target_speed := input_axis * max_speed
	var accel := ground_accel if is_on_floor else air_accel

	vel_side = move_toward(vel_side, target_speed, accel * delta)

	# Snap to stop when there is no input on the ground.
	if input_axis == 0.0 and is_on_floor:
		vel_side = move_toward(vel_side, 0.0, ground_friction * delta)

	# Recompose velocity: preserve the vertical component, replace horizontal.
	return right_dir * vel_side + up_dir * velocity.dot(up_dir)