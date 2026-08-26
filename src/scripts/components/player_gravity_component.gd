class_name PlayerGravityComponent
extends Node

# PlayerGravityComponent — a gravity CONSUMER, not an owner (ADR-0001 part 3).
#
# The world gravity vector lives in the `GravityAuthority` autoload. This node
# holds no vector, no target and no basis of its own: a cached copy could
# silently diverge from the authority, which is the forbidden
# `private_gravity_copy` pattern (control manifest, Foundation layer).
#
# What it still owns is the jump-tuning derivation. `initialize(max_speed)`
# turns the three designer-facing jump constants into the ascent/descent
# magnitudes and the fixed `jump_velocity`, then `Player._ready()` hands the
# baseline and the ratio to the authority. That math is UNCHANGED from the
# pre-migration code — this is a relocation of ownership, not a retune of feel
# (GDD R4, R5).

# ---------------------------------------------------------------
# EXPORTS (forwarded from Player facade)
# ---------------------------------------------------------------
@export var jump_height: float = 200.0
## Horizontal pixels traveled at max_speed while ascending to peak.
@export var jump_distance_to_peak: float = 128.0
## Horizontal pixels traveled at max_speed while descending to land.
@export var jump_distance_to_land: float = 80.0

# ---------------------------------------------------------------
# DERIVED STATE (written once, by initialize())
# ---------------------------------------------------------------
## Weaker pull on the way up, at the 1.0x baseline. This is also the value the
## authority is seeded with — the live, zone-scaled magnitude is
## `GravityAuthority.ascent_magnitude()`, never this field.
var gravity_ascent_mag: float = 0.0

## Stronger pull on the way down, at the 1.0x baseline.
var gravity_descent_mag: float = 0.0

## Fixed launch speed, read once by `PlayerJumpComponent`. Derived here and
## never written again by any path, including every `gravity_changed`
## broadcast — jump HEIGHT varies with zone gravity, launch speed does not
## (GDD R5, R10).
var jump_velocity: float = 0.0

# ---------------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------------
## Derive gravity magnitudes and jump velocity from jump params + max_speed.
## Call once in Player._ready(), before seeding GravityAuthority.
## [param max_speed] the player's horizontal run speed, in pixels per second.
func initialize(max_speed: float) -> void:
	var t_up: float   = jump_distance_to_peak / max_speed
	var t_down: float = jump_distance_to_land / max_speed

	gravity_ascent_mag  = (2.0 * jump_height) / (t_up   * t_up)
	gravity_descent_mag = (2.0 * jump_height) / (t_down * t_down)
	jump_velocity = (2.0 * jump_height) / t_up

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------
## The 1.0x ascent magnitude the authority scales every zone multiplier off.
## An accessor rather than a stored field: there is only one number here, and
## a second `baseline_ascent_mag` copy of it could drift.
func baseline_ascent_magnitude() -> float:
	return gravity_ascent_mag

## `ascent / descent` — the jump asymmetry, handed to the authority once at
## `initialize()` time and invariant thereafter (GDD AC4).
## Returns 0.0 before `initialize()`, which the authority's own guard refuses,
## rather than dividing by zero.
func ascent_descent_ratio() -> float:
	if gravity_descent_mag <= 0.0:
		push_error(
			"PlayerGravityComponent.ascent_descent_ratio() called before " +
			"initialize(). Returning 0.0 so GravityAuthority.initialize() " +
			"refuses the seed rather than shipping a silent 1.0 ratio."
		)
		return 0.0
	return gravity_ascent_mag / gravity_descent_mag

## Apply ascent/descent gravity to velocity (returns modified velocity).
##
## Reads the live vector and magnitudes from `GravityAuthority` on every call.
## The locals below are per-call by design — a member field holding the vector
## is the forbidden `private_gravity_copy`.
## [param delta] the physics step, in seconds.
## [param velocity] the body's current velocity.
## [param is_on_floor] when true the velocity is returned untouched.
func apply_gravity(delta: float, velocity: Vector2, is_on_floor: bool) -> Vector2:
	if is_on_floor:
		return velocity
	var grav_dir: Vector2 = GravityAuthority.gravity.normalized()
	var vel_up: float = velocity.dot(-grav_dir)  # positive while ascending
	# `> 0.0`, not `>= 0.0`: a velocity exactly perpendicular to gravity takes
	# the DESCENT branch. Apex frames land on this boundary, so flipping it
	# would change jump feel (GDD R4).
	var grav_mag: float = (
		GravityAuthority.ascent_magnitude() if vel_up > 0.0
		else GravityAuthority.descent_magnitude()
	)
	return velocity + grav_dir * grav_mag * delta
