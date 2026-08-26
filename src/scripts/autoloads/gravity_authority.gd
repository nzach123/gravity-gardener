# GravityAuthority — autoload. The single source of the world gravity vector.
#
# Zones declare, the authority owns, the player and props consume (ADR-0001).
# This file is decision parts 1 and 7 plus the part 4a direction ease: the node,
# its state, its public API, the two guards and the `_physics_process` turn.
# Deliberately absent until later stories:
#   - the `PhysicsServer2D` default-space write ................ story 006
#   - the prop registry body and the force-wake pass ........... story 007
#
# Reached only through the autoload singleton name. It carries NO `class_name`
# on purpose — a second global identifier for one node is forbidden by the
# control manifest (Foundation layer, source ADR-0001).
extends Node

## Remaining angle at or below which the ease stops interpolating and assigns
## `target_gravity` outright. 2.5 degrees, in radians.
##
## It makes "settled" one exact state instead of two competing ones: the snap
## writes the target vector itself, so the `==` idle guard in
## `_physics_process()` is exact and needs no approximate test. The pure ease
## never reaches `is_equal_approx` inside the GDD AC5 budget — it needs roughly
## 19 steps (~317 ms) — so a threshold is required, not merely convenient.
##
## The value is the smallest one with margin on both axes at the default rate:
## it snaps at step 5 = 83.3 ms, 16.7 ms under AC5's 100 ms budget, and clears
## the 1.9919-degree step-5 residual by +0.51 degrees. Steps 1-4 are unchanged
## by it; only the tail is truncated.
const DIRECTION_SETTLE_EPSILON: float = 0.0436332


## Emitted after every accepted gravity change. `direction` is normalized;
## `multiplier` is the zone strength relative to the jump-tuning baseline.
## Consumers derive their own basis and magnitudes from this — they never
## cache the vector (`private_gravity_copy` is forbidden).
signal gravity_changed(direction: Vector2, multiplier: float)

## Angular ease rate for the turn from `gravity` toward `target_gravity`.
## Exported so it is a designer knob rather than a literal buried in code
## (TR-gravity-011). `_physics_process()` reads it, and the default below is
## the only place the rate is written — a raised rate turns faster.
@export var direction_ease_rate: float = 32.0

## The live world gravity vector. Length is the current ascent magnitude;
## every consumer that wants direction reads `gravity.normalized()`.
var gravity: Vector2 = Vector2.ZERO

## Where `gravity` is heading. `reset_to()` snaps both together; `set_gravity()`
## moves this one and lets the `_physics_process()` ease carry `gravity`
## after it.
var target_gravity: Vector2 = Vector2.ZERO

## `-gravity.normalized()`. Derived on every write of `gravity`, never stored
## independently, so it cannot drift from the vector (GDD R1).
var up_dir: Vector2 = Vector2.ZERO

## `Vector2(-up_dir.y, up_dir.x)` — the rightward screen axis for the current
## orientation (GDD R1).
var right_dir: Vector2 = Vector2.ZERO

## Ascent magnitude at multiplier 1.0. Seeded once by `initialize()` from the
## player's jump constants.
var baseline_ascent_mag: float = 0.0

## `ascent / descent`. Written ONLY by `initialize()`. No `set_gravity()` or
## `reset_to()` path may touch it — that invariance is GDD AC4.
var ascent_descent_ratio: float = 1.0

var _current_multiplier: float = 1.0
var _initialized: bool = false


## Seeds the authority with the player's jump-derived constants. Public and
## seedable on purpose: it is what makes this node testable headless with no
## `Player` and no rendered scene. Called from `Player._ready()`.
##
## Safe to call again — a scene reload re-runs `Player._ready()` while this
## autoload survives, so re-seeding is the normal restart path.
func initialize(p_baseline_ascent_mag: float, p_ascent_descent_ratio: float) -> void:
	if p_baseline_ascent_mag <= 0.0 or p_ascent_descent_ratio <= 0.0:
		push_error(
			"GravityAuthority.initialize() refused: baseline_ascent_mag and " +
			"ascent_descent_ratio must both be positive (got %f, %f). " %
			[p_baseline_ascent_mag, p_ascent_descent_ratio] +
			"A zero ratio makes descent_magnitude() undefined."
		)
		return
	baseline_ascent_mag = p_baseline_ascent_mag
	ascent_descent_ratio = p_ascent_descent_ratio
	_initialized = true


## Snaps gravity to `direction` immediately, with no ease. This is the level
## load and restart path — `LevelRoot._ready()` calls it with the level's
## declared default so a restart never inherits the gravity the player died in.
func reset_to(direction: Vector2, multiplier: float) -> void:
	if not _accepts(direction, multiplier, "reset_to"):
		return
	_apply(direction, multiplier)
	gravity = target_gravity
	_derive_basis()
	gravity_changed.emit(direction.normalized(), multiplier)


## Declares a new gravity for the world. This is the zone path — `gravity`
## turns toward the new direction over the `_physics_process()` ease rather
## than snapping. Strength does NOT ease: `_apply()` has already moved the
## magnitude by the time this returns (GDD R3).
func set_gravity(direction: Vector2, multiplier: float) -> void:
	if not _accepts(direction, multiplier, "set_gravity"):
		return
	_apply(direction, multiplier)
	gravity_changed.emit(direction.normalized(), multiplier)


## Adds a prop to the wake registry. Signature only — the registry body and the
## force-wake pass are story 007. `PropBody` (ADR-0011) is written against this
## interface, so the method must exist now even though it does nothing yet.
@warning_ignore("unused_parameter")
func register_prop(prop: RigidBody2D) -> void:
	pass  # Story 007


## Removes a prop from the wake registry. Called from `PropBody._exit_tree()`,
## which covers both out-of-bounds freeing and scene reload. Signature only —
## body is story 007.
@warning_ignore("unused_parameter")
func unregister_prop(prop: RigidBody2D) -> void:
	pass  # Story 007


## Current ascent (rising) gravity magnitude — the baseline scaled by the
## active zone multiplier.
func ascent_magnitude() -> float:
	return baseline_ascent_mag * _current_multiplier


## Current descent (falling) gravity magnitude. DERIVED from ascent, never
## stored: there is no second field that can drift out of ratio, which is what
## makes GDD AC4 structural instead of conventional.
func descent_magnitude() -> float:
	return ascent_magnitude() / ascent_descent_ratio


## Turns `gravity` toward `target_gravity` by one step. Direction only — the
## magnitude is read from the already-snapped `ascent_magnitude()` and is never
## eased (ADR-0001 part 3 drops the old `move_toward` on the vector length).
##
## `_physics_process`, not `_process`, is mandatory rather than stylistic: it is
## called before every physics step, so story 006's space write will land before
## the step that integrates it and GDD AC12's same-frame guarantee holds.
## `_process` has no defined phase relationship to the fixed-timestep loop.
##
## Emits nothing. `gravity_changed` fires once per accepted change, from
## `set_gravity()` / `reset_to()`. A consumer that wants the live eased vector
## reads `GravityAuthority.gravity` directly, which is the control manifest's
## required read path anyway.
func _physics_process(delta: float) -> void:
	# The settled path costs one Vector2 compare. The snap below assigns the
	# target vector itself, so `==` is exact here rather than approximate.
	if gravity == target_gravity:
		return

	var new_angle: float = lerp_angle(
		gravity.angle(),
		target_gravity.angle(),
		clampf(direction_ease_rate * delta, 0.0, 1.0)
	)
	gravity = Vector2.RIGHT.rotated(new_angle) * ascent_magnitude()

	if absf(angle_difference(gravity.angle(), target_gravity.angle())) < DIRECTION_SETTLE_EPSILON:
		gravity = target_gravity

	# Both writes of `gravity` above land in this one derivation, so the basis
	# cannot fall a frame behind the vector (GDD R1).
	_derive_basis()


# ── internals ────────────────────────────────────────────────────────────────

# Validates a broadcast request. Order is load-bearing: initialize gate, then
# direction, then multiplier — and NO state is touched until all three pass.
# AC7 requires gravity to be *unchanged* after a rejection, which a partially
# applied write would violate.
#
# Uses push_error(), never assert(): assert() compiles out of release exports,
# so the guard would silently vanish in the build that matters.
func _accepts(direction: Vector2, multiplier: float, caller: String) -> bool:
	if not _initialized:
		push_error(
			"GravityAuthority.%s() called before initialize(). " % caller +
			"Refusing to broadcast — a broadcast here would silently ship a " +
			"1.0 ascent/descent ratio and lose the R4 jump asymmetry."
		)
		return false
	if direction.is_zero_approx():
		push_warning(
			"GravityAuthority.%s() rejected a zero-length direction. " % caller +
			"Gravity is unchanged."
		)
		return false
	if multiplier <= 0.0:
		push_warning(
			"GravityAuthority.%s() rejected multiplier %f — must be > 0. " %
			[caller, multiplier] + "Gravity is unchanged."
		)
		return false
	return true


# Commits an accepted request. Never touches `ascent_descent_ratio` or
# `baseline_ascent_mag` — those belong to initialize() alone (GDD AC4).
func _apply(direction: Vector2, multiplier: float) -> void:
	_current_multiplier = multiplier
	target_gravity = direction.normalized() * ascent_magnitude()


# The single place `up_dir` / `right_dir` are written. Called on every write of
# `gravity` so the basis cannot fall out of step with the vector (GDD R1).
func _derive_basis() -> void:
	up_dir = -gravity.normalized()
	right_dir = Vector2(-up_dir.y, up_dir.x)
