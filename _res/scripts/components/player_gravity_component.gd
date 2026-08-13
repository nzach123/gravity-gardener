class_name PlayerGravityComponent
extends Node

# ---------------------------------------------------------------
# EXPORTS (forwarded from Player facade)
# ---------------------------------------------------------------
@export var jump_height: float = 200.0
## Horizontal pixels traveled at max_speed while ascending to peak.
@export var jump_distance_to_peak: float = 128.0
## Horizontal pixels traveled at max_speed while descending to land.
@export var jump_distance_to_land: float = 80.0

# ---------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------
var gravity: Vector2 = Vector2.ZERO        # current gravity, may rotate via GravityZone
var target_gravity: Vector2 = Vector2.ZERO # lerp destination
var gravity_ascent_mag: float = 0.0        # weaker pull on the way up
var gravity_descent_mag: float = 0.0       # stronger pull on the way down
var ascent_descent_ratio: float = 1.0      # preserved across gravity zone changes
var up_dir: Vector2 = Vector2.UP
var right_dir: Vector2 = Vector2.RIGHT
var jump_velocity: float = 0.0             # derived, read by JumpComponent

# ---------------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------------
## Derive gravity magnitudes and jump velocity from jump params + max_speed.
## Call once in Player._ready().
func initialize(max_speed: float) -> void:
	var t_up: float   = jump_distance_to_peak / max_speed
	var t_down: float = jump_distance_to_land / max_speed

	gravity_ascent_mag  = (2.0 * jump_height) / (t_up   * t_up)
	gravity_descent_mag = (2.0 * jump_height) / (t_down * t_down)
	jump_velocity = (2.0 * jump_height) / t_up
	ascent_descent_ratio = gravity_ascent_mag / gravity_descent_mag

	# Seed the live gravity vector using the ascent magnitude as a neutral default.
	gravity = Vector2(0.0, gravity_ascent_mag)
	target_gravity = gravity

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------
## Called by Player.set_gravity() when a GravityZone changes gravity.
func set_gravity(new_vector: Vector2, max_speed: float) -> void:
	var new_mag := new_vector.length()
	if new_mag <= 0.0:
		return
	gravity_ascent_mag  = new_mag
	gravity_descent_mag = gravity_ascent_mag / ascent_descent_ratio
	jump_velocity       = sqrt(2.0 * jump_height * gravity_ascent_mag)
	target_gravity      = new_vector

## Derive up_dir and right_dir from current gravity.
## Call at the top of _physics_process before any other component.
func update_derived_dirs() -> void:
	up_dir = -gravity.normalized()
	right_dir = Vector2(-up_dir.y, up_dir.x)

## Smoothly rotate and adjust magnitude toward target_gravity.
func update_gravity_lerp(delta: float) -> void:
	if gravity.is_equal_approx(target_gravity):
		return
	var new_angle := lerp_angle(gravity.angle(), target_gravity.angle(), clampf(32.0 * delta, 0.0, 1.0))
	var new_mag := move_toward(gravity.length(), target_gravity.length(), 25.0 * delta)
	gravity = Vector2.RIGHT.rotated(new_angle) * new_mag

## Apply ascent/descent gravity to velocity (returns modified velocity).
func apply_gravity(delta: float, velocity: Vector2, is_on_floor: bool) -> Vector2:
	if is_on_floor:
		return velocity
	var vel_up := velocity.dot(-gravity.normalized())  # positive while ascending
	var grav_mag: float = gravity_ascent_mag if vel_up > 0.0 else gravity_descent_mag
	return velocity + gravity.normalized() * grav_mag * delta