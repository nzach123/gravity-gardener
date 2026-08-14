class_name PlayerJumpComponent
extends Node

# ---------------------------------------------------------------
# EXPORTS (forwarded from Player facade)
# ---------------------------------------------------------------
@export var min_jump_velocity: float = 100.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

# ---------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------
var jump_velocity: float = 0.0   # set by GravityComponent via set_jump_velocity()
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jumping: bool = false
var was_on_floor: bool = false

# ---------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------
signal jumped
signal landed

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------
## Called by GravityComponent after deriving jump_velocity.
func set_jump_velocity(v: float) -> void:
	jump_velocity = v

## Process coyote time, jump buffer, variable-height release, and landing detection.
## Returns modified velocity.
func update(
	delta: float,
	velocity: Vector2,
	is_on_floor: bool,
	up_dir: Vector2,
	right_dir: Vector2
) -> Vector2:
	# Coyote time: keep the ability to jump briefly after walking off a ledge.
	coyote_timer = coyote_time if is_on_floor else coyote_timer - delta
	jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else jump_buffer_timer - delta

	# Consume the buffer when coyote window is open.
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		var vel_side := velocity.dot(right_dir)
		velocity = right_dir * vel_side + up_dir * jump_velocity
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		is_jumping = true
		jumped.emit()

	# Variable jump height: cutting the button early reduces upward velocity.
	var vel_up := velocity.dot(up_dir)
	if Input.is_action_just_released("jump") and vel_up > 0.0:
		if vel_up > min_jump_velocity:
			velocity -= up_dir * (vel_up - min_jump_velocity)
		is_jumping = false

	# Landing detection.
	if is_on_floor and not was_on_floor:
		is_jumping = false
		landed.emit()

	was_on_floor = is_on_floor
	return velocity