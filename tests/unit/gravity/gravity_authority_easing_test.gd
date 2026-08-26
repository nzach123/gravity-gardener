# Direction-ease tests for the GravityAuthority autoload (story GA-002, ADR-0001
# decision parts 1, 3 and 4a).
#
# Story GA-001 built the node, its API and its guards; the turn from `gravity`
# toward `target_gravity` was deliberately absent. This suite covers the turn:
# that direction eases while strength snaps (GDD R3), that the turn completes
# inside the GDD AC5 100 ms budget with margin, that it lives in the physics
# callback, that it is driven by the exported rate rather than a literal
# (TR-gravity-011), and that it neither re-emits nor drifts once settled.
#
# The ease is driven by calling `_physics_process(delta)` directly with a fixed
# delta. Real frames are never awaited: `Physics 2D > Default Physics FPS` would
# then decide the step count, and the testing standards require determinism.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const AUTHORITY_SCENE := "res://src/scripts/autoloads/gravity_authority.tscn"
const AUTHORITY_SCRIPT := "res://src/scripts/autoloads/gravity_authority.gd"

# GDD section 4 "Current values" baseline: g_ascent=2990.72, ratio=0.390625.
const BASELINE_ASCENT := 2990.72
const ASCENT_DESCENT_RATIO := 0.390625

# 60 physics ticks per second — the project default and the delta every probed
# number in the story was measured at.
const STEP := 1.0 / 60.0

# GDD AC5. A 90-degree change must be complete by here.
const AC5_BUDGET_SECONDS := 0.100

# QA-plan addendum, 2026-08-25: assert the margin, not only the pass.
#
# The floors below are the measured values, not the addendum's rounded prose.
# The addendum rounds UP in both places: the headroom is 100 - 83.333 = 16.667
# ms, quoted as "16.7 ms", and the residual margin is 2.5 - 1.99194 = 0.50806
# degrees, quoted as "+0.51 degrees". A floor set at the quoted figure fails a
# correct implementation by ~33 microseconds and ~0.002 degrees respectively.
const EXPECTED_SETTLE_STEP := 5
const EXPECTED_HEADROOM_SECONDS := 0.01666
const EXPECTED_STEP_FIVE_RESIDUAL_DEGREES := 1.9919
const EXPECTED_RESIDUAL_MARGIN_DEGREES := 0.508

const TOLERANCE := 0.0001
const ANGLE_TOLERANCE := 0.0005
const SETTLE_STEP_CEILING := 240

var _authority: Node
var _signal_count: int = 0
var _last_direction: Vector2 = Vector2.ZERO
var _last_multiplier: float = 0.0


func before_test() -> void:
	_authority = _make_authority()
	_signal_count = 0
	_last_direction = Vector2.ZERO
	_last_multiplier = 0.0


func after_test() -> void:
	_authority = null


# Seeded and settled at DOWN, which is the story's stated fixture. The signal
# counter is connected AFTER reset_to() so the fixture's own emission is not
# charged against the per-test counts.
func _make_authority() -> Node:
	var scene: PackedScene = load(AUTHORITY_SCENE)
	var authority: Node = auto_free(scene.instantiate())
	authority.initialize(BASELINE_ASCENT, ASCENT_DESCENT_RATIO)
	authority.reset_to(Vector2.DOWN, 1.0)
	authority.gravity_changed.connect(_on_gravity_changed)
	return authority


func _on_gravity_changed(direction: Vector2, multiplier: float) -> void:
	_signal_count += 1
	_last_direction = direction
	_last_multiplier = multiplier


# ── AC-1 — a 90-degree turn completes inside 100 ms and never reverses ────────

func test_every_ninety_degree_transition_settles_within_the_ac5_budget() -> void:
	# All four axis-to-axis turns, not one: UP to LEFT crosses the +/-pi
	# boundary, where a naive subtraction-based monotonicity check reports a
	# false reversal. Every comparison below goes through angle_difference().
	var transitions: Array[Array] = [
		[Vector2.DOWN, Vector2.RIGHT],
		[Vector2.RIGHT, Vector2.UP],
		[Vector2.UP, Vector2.LEFT],
		[Vector2.LEFT, Vector2.DOWN],
	]
	for transition: Array in transitions:
		var from: Vector2 = transition[0]
		var to: Vector2 = transition[1]
		_authority.reset_to(from, 1.0)

		var samples: PackedFloat32Array = _run_transition(to)
		var steps: int = samples.size() - 1

		assert_int(steps).is_equal(EXPECTED_SETTLE_STEP)
		assert_bool(float(steps) * STEP <= AC5_BUDGET_SECONDS).is_true()
		assert_bool(_is_monotonic(samples)).is_true()
		assert_that(_authority.gravity).is_equal(_authority.target_gravity)


func test_a_hundred_and_eighty_degree_flip_terminates_and_stays_monotonic() -> void:
	# lerp_angle's shortest-path choice is ambiguous at exactly pi, so this case
	# asserts only that the turn terminates and never reverses — not which way
	# it goes round.
	var samples: PackedFloat32Array = _run_transition(Vector2.UP)

	assert_bool(samples.size() - 1 < SETTLE_STEP_CEILING).is_true()
	assert_bool(_is_monotonic(samples)).is_true()
	assert_that(_authority.gravity).is_equal(_authority.target_gravity)


func test_the_settle_snap_leaves_the_stated_headroom_under_the_ac5_budget() -> void:
	# QA-plan addendum. Asserting only "<= 100 ms" would pass at zero margin, so
	# a later direction_ease_rate change that erodes the headroom would land
	# silently. The step count and the headroom are both pinned.
	var steps: int = _run_transition(Vector2.RIGHT).size() - 1
	var elapsed: float = float(steps) * STEP

	assert_int(steps).is_equal(EXPECTED_SETTLE_STEP)
	assert_float(elapsed).is_equal_approx(0.0833, 0.0005)
	assert_float(AC5_BUDGET_SECONDS - elapsed).is_greater_equal(EXPECTED_HEADROOM_SECONDS)


func test_the_settle_epsilon_clears_the_step_five_residual_by_half_a_degree() -> void:
	# The other half of the margin assertion. The step-5 residual is not
	# observable after the fact (the snap overwrites it in the same frame), so
	# it is projected from the live step-4 residual using the ease's own
	# retained-error factor.
	_authority.set_gravity(Vector2.RIGHT, 1.0)
	_step(4)

	var residual_four: float = _remaining_angle()
	var retained: float = 1.0 - clampf(float(_authority.direction_ease_rate) * STEP, 0.0, 1.0)
	var residual_five: float = residual_four * retained
	var epsilon: float = _settle_epsilon()

	# Step 4 must NOT have snapped — otherwise the projection describes a
	# threshold that is never reached.
	assert_bool(_authority.gravity != _authority.target_gravity).is_true()
	assert_bool(residual_four > epsilon).is_true()
	assert_float(rad_to_deg(residual_five)).is_equal_approx(
		EXPECTED_STEP_FIVE_RESIDUAL_DEGREES, 0.001
	)
	assert_float(rad_to_deg(epsilon - residual_five)).is_greater_equal(
		EXPECTED_RESIDUAL_MARGIN_DEGREES
	)


# ── AC-2 — strength snaps while direction eases (GDD R3) ─────────────────────

func test_strength_reaches_its_new_value_before_any_ease_frame_runs() -> void:
	var angle_before: float = float(_authority.gravity.angle())
	_authority.set_gravity(Vector2.RIGHT, 2.0)

	# No _physics_process step has run yet.
	assert_float(_authority.ascent_magnitude()).is_equal_approx(BASELINE_ASCENT * 2.0, TOLERANCE)
	assert_float(_authority.descent_magnitude()).is_equal_approx(
		BASELINE_ASCENT * 2.0 / ASCENT_DESCENT_RATIO, 0.01
	)
	assert_float(float(_authority.gravity.angle())).is_equal_approx(angle_before, ANGLE_TOLERANCE)

	# The first ease frame carries the full new magnitude too. An implementation
	# that ramps magnitude alongside direction passes an end-state check and
	# fails right here.
	_step(1)
	assert_float(float(_authority.gravity.length())).is_equal_approx(
		BASELINE_ASCENT * 2.0, 0.01
	)
	assert_bool(absf(_remaining_angle()) > 0.0).is_true()


# ── AC-3 — the ease runs in the physics callback ─────────────────────────────

func test_the_ease_is_declared_in_physics_process_and_no_process_exists() -> void:
	# A source grep is the honest test: headlessly, no behavioural check can
	# tell the two callbacks apart. If _process is ever needed for an unrelated
	# purpose, narrow this to "the ease body is not inside _process".
	var code: String = _authority_code()
	assert_bool(code.contains("func _physics_process(delta: float) -> void:")).is_true()
	assert_bool(code.contains("func _process(")).is_false()


# ── AC-4 / AC-5 — the exported rate is what drives the ease (TR-gravity-011) ──

func test_a_lower_ease_rate_takes_strictly_more_steps() -> void:
	var slow: Node = _make_authority()
	slow.direction_ease_rate = 8.0

	var fast_steps: int = _settle_steps(_authority, Vector2.RIGHT)
	var slow_steps: int = _settle_steps(slow, Vector2.RIGHT)

	assert_int(fast_steps).is_equal(EXPECTED_SETTLE_STEP)
	assert_int(slow_steps).is_greater(fast_steps)


func test_the_literal_ease_rate_appears_only_on_the_export_default_line() -> void:
	# Required alongside the duration test above, not instead of it. A rate
	# hardcoded inside the ease body still produces a correct-looking 83 ms
	# result at the default value, so a duration-only test passes on the exact
	# defect TR-gravity-011 names.
	var source: String = FileAccess.get_file_as_string(AUTHORITY_SCRIPT)
	var carrying_lines: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if line.contains("32.0"):
			carrying_lines.append(line.strip_edges())

	assert_int(carrying_lines.size()).is_equal(1)
	assert_str(carrying_lines[0]).is_equal("@export var direction_ease_rate: float = 32.0")


# ── AC-6 — no magnitude easing survives ──────────────────────────────────────

func test_no_move_toward_magnitude_ease_remains_on_the_authority() -> void:
	assert_bool(_authority_code().contains("move_toward")).is_false()


func test_length_is_the_snapped_ascent_magnitude_on_every_ease_frame() -> void:
	# The multiplier MUST change here. Held at 1.0 the length is constant
	# anyway, and a surviving magnitude ease would be invisible.
	_authority.set_gravity(Vector2.RIGHT, 2.0)
	var expected: float = float(_authority.ascent_magnitude())
	assert_float(expected).is_equal_approx(BASELINE_ASCENT * 2.0, TOLERANCE)

	var frames: int = 0
	while _authority.gravity != _authority.target_gravity and frames < SETTLE_STEP_CEILING:
		_step(1)
		frames += 1
		assert_float(float(_authority.gravity.length())).is_equal_approx(expected, 0.01)
	assert_int(frames).is_equal(EXPECTED_SETTLE_STEP)


# ── AC-7 — the settled state costs nothing ───────────────────────────────────

func test_a_settled_authority_is_bit_identical_after_a_hundred_idle_frames() -> void:
	# Bit-identical, not approximate. A loop that keeps running lerp_angle
	# against an already-reached target accumulates float drift, which an
	# approximate assertion hides until it shows up in play. The settle snap is
	# what gives this criterion an exact reference to compare against.
	_settle_steps(_authority, Vector2.RIGHT)

	var gravity_before: Vector2 = _authority.gravity
	var up_before: Vector2 = _authority.up_dir
	var right_before: Vector2 = _authority.right_dir
	_signal_count = 0

	_step(100)

	assert_bool(_authority.gravity == gravity_before).is_true()
	assert_bool(_authority.up_dir == up_before).is_true()
	assert_bool(_authority.right_dir == right_before).is_true()
	assert_that(_authority.gravity).is_equal(_authority.target_gravity)
	assert_int(_signal_count).is_equal(0)


# ── AC-8 — the signal fires once per change, not once per frame ──────────────

func test_gravity_changed_fires_once_across_a_whole_ease() -> void:
	_authority.set_gravity(Vector2.RIGHT, 1.0)
	_step(60)

	assert_int(_signal_count).is_equal(1)
	# The payload is the TARGET direction, not an intermediate eased one.
	assert_that(_last_direction).is_equal(Vector2.RIGHT)
	assert_float(_last_multiplier).is_equal_approx(1.0, TOLERANCE)


func test_a_mid_ease_retarget_emits_twice_and_does_not_snap() -> void:
	# GDD R8 last-entered-wins: a second zone claims the world before the first
	# turn settles.
	_authority.set_gravity(Vector2.RIGHT, 1.0)
	_step(2)
	assert_bool(_authority.gravity != _authority.target_gravity).is_true()

	_authority.set_gravity(Vector2.UP, 1.0)

	assert_int(_signal_count).is_equal(2)
	assert_that(_last_direction).is_equal(Vector2.UP)
	# Retarget, not snap: the vector must still have distance to cover.
	assert_bool(_authority.gravity != _authority.target_gravity).is_true()
	assert_bool(_remaining_angle() > _settle_epsilon()).is_true()

	_step(60)
	assert_that(_authority.gravity).is_equal(_authority.target_gravity)
	assert_float(float(_authority.gravity.normalized().angle())).is_equal_approx(
		Vector2.UP.angle(), ANGLE_TOLERANCE
	)
	assert_int(_signal_count).is_equal(2)


# ── shared helpers ───────────────────────────────────────────────────────────

func _step(count: int) -> void:
	for _i: int in count:
		_authority._physics_process(STEP)


# Runs a transition on the fixture authority to completion, returning the angle
# after each step with the pre-transition angle at index 0.
func _run_transition(to: Vector2) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array([_authority.gravity.angle()])
	_authority.set_gravity(to, 1.0)
	while _authority.gravity != _authority.target_gravity and samples.size() <= SETTLE_STEP_CEILING:
		_step(1)
		samples.append(_authority.gravity.angle())
	return samples


# Steps `authority` until it settles, returning the step count.
func _settle_steps(authority: Node, to: Vector2) -> int:
	authority.set_gravity(to, 1.0)
	var steps: int = 0
	while authority.gravity != authority.target_gravity and steps < SETTLE_STEP_CEILING:
		authority._physics_process(STEP)
		steps += 1
	return steps


func _remaining_angle() -> float:
	return absf(angle_difference(_authority.gravity.angle(), _authority.target_gravity.angle()))


# Reads DIRECTION_SETTLE_EPSILON off the script itself rather than restating the
# number, so the margin assertions track the source constant.
func _settle_epsilon() -> float:
	var script: GDScript = load(AUTHORITY_SCRIPT)
	return float(script.get_script_constant_map()["DIRECTION_SETTLE_EPSILON"])


# True when no consecutive pair of samples reverses direction. Wrapped deltas
# only — a plain subtraction reports a false reversal at the +/-pi boundary.
func _is_monotonic(samples: PackedFloat32Array) -> bool:
	var sign_seen: float = 0.0
	for index: int in range(1, samples.size()):
		var delta: float = angle_difference(samples[index - 1], samples[index])
		if is_zero_approx(delta):
			continue
		var delta_sign: float = signf(delta)
		if sign_seen != 0.0 and delta_sign != sign_seen:
			return false
		sign_seen = delta_sign
	return true


# The authority source with comment-only lines stripped, so a rule quoted in a
# doc comment can neither satisfy nor break a source scan.
func _authority_code() -> String:
	var code: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(AUTHORITY_SCRIPT).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	return "\n".join(code)
