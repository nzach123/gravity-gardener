class_name PlayerWallJumpComponent
extends Node

# ---------------------------------------------------------------
# EXPORTS (forwarded from Player facade)
# ---------------------------------------------------------------
@export var wall_jump_h_force: float = 450.0
@export var wall_jump_v_force: float = 800.0
@export var wall_jump_cooldown: float = 0.15
@export var enable_wall_jump: bool = false

# ---------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------
var wall_jump_timer: float = 0.0

# ---------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------
signal wall_jumped

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------
## Attempt a wall jump if conditions are met.
## Returns modified velocity.
func try(
	delta: float,
	velocity: Vector2,
	is_on_floor: bool,
	is_on_wall: bool,
	up_dir: Vector2,
	get_wall_normal: Callable
) -> Vector2:
	wall_jump_timer = maxf(0.0, wall_jump_timer - delta)

	if is_on_wall and not is_on_floor and wall_jump_timer <= 0.0:
		if Input.is_action_just_pressed("jump"):
			velocity = get_wall_normal.call() * wall_jump_h_force + up_dir * wall_jump_v_force
			wall_jump_timer = wall_jump_cooldown
			wall_jumped.emit()

	return velocity