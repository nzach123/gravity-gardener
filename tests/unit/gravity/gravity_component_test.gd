# Unit tests for PlayerGravityComponent
#
# This component owns gravity magnitude derivation, smooth lerp toward target,
# up_dir/right_dir derivation, and ascent/descent gravity application.
# All tests are pure math — no scene tree required.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const MAX_SPEED: float = 350.0
const DELTA: float = 1.0 / 60.0

var _comp: PlayerGravityComponent


func before_test() -> void:
	_comp = auto_free(PlayerGravityComponent.new())
	_comp.jump_height = 200.0
	_comp.jump_distance_to_peak = 128.0
	_comp.jump_distance_to_land = 80.0
	_comp.initialize(MAX_SPEED)


# ── initialize() ─────────────────────────────────────────────────────────────

func test_initialize_sets_gravity_to_down_ascent_magnitude() -> void:
	assert_float(_comp.gravity.x).is_equal(0.0)
	assert_float(_comp.gravity.y).is_equal_approx(_comp.gravity_ascent_mag, 0.01)


func test_initialize_sets_target_gravity_equal_to_gravity() -> void:
	assert_that(_comp.target_gravity).is_equal(_comp.gravity)


func test_initialize_derives_positive_ascent_magnitude() -> void:
	assert_float(_comp.gravity_ascent_mag).is_greater(0.0)


func test_initialize_derives_positive_descent_magnitude() -> void:
	assert_float(_comp.gravity_descent_mag).is_greater(0.0)


func test_initialize_descent_is_stronger_than_ascent() -> void:
	# Descent gravity should be stronger (faster fall than rise)
	assert_float(_comp.gravity_descent_mag).is_greater(_comp.gravity_ascent_mag)


func test_initialize_derives_positive_jump_velocity() -> void:
	assert_float(_comp.jump_velocity).is_greater(0.0)


func test_initialize_preserves_ascent_descent_ratio() -> void:
	var expected_ratio := _comp.gravity_ascent_mag / _comp.gravity_descent_mag
	assert_float(_comp.ascent_descent_ratio).is_equal(expected_ratio)


func test_initialize_captures_baseline_as_1x_reference() -> void:
	# Zone multipliers scale off this, so it must equal the derived ascent
	# magnitude at startup (GDD R7).
	assert_float(_comp.baseline_ascent_mag).is_equal(_comp.gravity_ascent_mag)
	assert_float(_comp.baseline_ascent_mag).is_greater(0.0)


# ── set_gravity() ────────────────────────────────────────────────────────────

func test_set_gravity_points_target_along_given_direction() -> void:
	# Arrange / Act — direction is normalized, magnitude comes from the baseline
	_comp.set_gravity(Vector2.UP, 1.0)
	# Assert
	assert_that(_comp.target_gravity).is_equal(Vector2(0.0, -_comp.baseline_ascent_mag))


func test_set_gravity_scales_ascent_magnitude_by_multiplier() -> void:
	# Arrange
	var baseline := _comp.baseline_ascent_mag
	# Act
	_comp.set_gravity(Vector2.DOWN, 2.0)
	# Assert
	assert_float(_comp.gravity_ascent_mag).is_equal_approx(baseline * 2.0, 0.01)


func test_set_gravity_ignores_direction_magnitude() -> void:
	# Regression (GDD R7): a long direction vector must not leak its length into
	# strength — that was the failure mode of the old absolute-strength API.
	_comp.set_gravity(Vector2(0.0, 5000.0), 1.0)
	assert_float(_comp.gravity_ascent_mag).is_equal_approx(_comp.baseline_ascent_mag, 0.01)


func test_set_gravity_preserves_ascent_descent_ratio() -> void:
	# Arrange
	var ratio_before := _comp.ascent_descent_ratio
	# Act
	_comp.set_gravity(Vector2.UP, 0.5)
	# Assert
	assert_float(_comp.ascent_descent_ratio).is_equal(ratio_before)


func test_set_gravity_ignores_zero_length_direction() -> void:
	var target_before := _comp.target_gravity
	_comp.set_gravity(Vector2.ZERO, 1.0)
	assert_that(_comp.target_gravity).is_equal(target_before)


func test_set_gravity_ignores_non_positive_multiplier() -> void:
	# A zero or negative multiplier would invert or cancel gravity; reject it
	# rather than let a mis-authored zone produce undefined movement.
	var target_before := _comp.target_gravity
	_comp.set_gravity(Vector2.UP, 0.0)
	assert_that(_comp.target_gravity).is_equal(target_before)
	_comp.set_gravity(Vector2.UP, -1.0)
	assert_that(_comp.target_gravity).is_equal(target_before)


func test_set_gravity_leaves_jump_velocity_unchanged() -> void:
	# GDD R5: launch speed is fixed, so jump HEIGHT varies with zone gravity
	# (h = v^2 / 2g). This inverts the previous preserve-height behavior.
	var jv_before := _comp.jump_velocity
	_comp.set_gravity(Vector2.DOWN, 2.0)
	assert_float(_comp.jump_velocity).is_equal(jv_before)


func test_set_gravity_halving_gravity_doubles_jump_height() -> void:
	# GDD AC3 — the traversal lever this whole change exists to enable.
	var v := _comp.jump_velocity
	var height_at_baseline := (v * v) / (2.0 * _comp.gravity_ascent_mag)

	_comp.set_gravity(Vector2.DOWN, 0.5)
	var height_at_half := (v * v) / (2.0 * _comp.gravity_ascent_mag)

	assert_float(height_at_half).is_equal_approx(height_at_baseline * 2.0, 0.01)


# ── update_derived_dirs() ────────────────────────────────────────────────────

func test_derived_dirs_default_gravity_is_down() -> void:
	_comp.update_derived_dirs()
	assert_that(_comp.up_dir).is_equal(Vector2.UP)
	assert_that(_comp.right_dir).is_equal(Vector2.RIGHT)


func test_derived_dirs_up_gravity_flips_up_dir() -> void:
	_comp.gravity = Vector2(0.0, -980.0)
	_comp.update_derived_dirs()
	assert_that(_comp.up_dir).is_equal(Vector2.DOWN)


func test_derived_dirs_right_gravity_rotates_dirs_90_degrees() -> void:
	_comp.gravity = Vector2(980.0, 0.0)
	_comp.update_derived_dirs()
	assert_that(_comp.up_dir).is_equal(Vector2.LEFT)
	assert_that(_comp.right_dir).is_equal(Vector2.UP)


func test_derived_dirs_up_and_right_are_perpendicular() -> void:
	_comp.gravity = Vector2(693.0, 693.0)  # diagonal
	_comp.update_derived_dirs()
	var dot := _comp.up_dir.dot(_comp.right_dir)
	assert_float(dot).is_equal_approx(0.0, 0.0001)


# ── apply_gravity() ──────────────────────────────────────────────────────────

func test_apply_gravity_returns_velocity_unchanged_when_on_floor() -> void:
	var vel := Vector2(100.0, 0.0)
	var result := _comp.apply_gravity(DELTA, vel, true)
	assert_that(result).is_equal(vel)


func test_apply_gravity_increases_downward_velocity_when_falling() -> void:
	# Player is already moving downward (positive y in default gravity)
	var vel := Vector2(0.0, 100.0)
	var result := _comp.apply_gravity(DELTA, vel, false)
	assert_float(result.y).is_greater(vel.y)


func test_apply_gravity_uses_ascent_magnitude_when_moving_up() -> void:
	# Player is moving upward (negative y in default gravity)
	var vel := Vector2(0.0, -100.0)
	var result := _comp.apply_gravity(DELTA, vel, false)
	# Ascent gravity is weaker — velocity should still be negative but closer to zero
	assert_float(result.y).is_greater(vel.y)  # less negative = greater


func test_apply_gravity_uses_descent_magnitude_when_moving_down() -> void:
	var vel := Vector2(0.0, 10.0)  # small downward velocity
	var result := _comp.apply_gravity(DELTA, vel, false)
	# Descent gravity is stronger — should add more than ascent would
	var vel_up := Vector2(0.0, -10.0)
	var result_up := _comp.apply_gravity(DELTA, vel_up, false)
	var delta_down := result.y - vel.y
	var delta_up := result_up.y - vel_up.y
	assert_float(delta_down).is_greater(delta_up)


# ── update_gravity_lerp() ────────────────────────────────────────────────────

func test_gravity_lerp_moves_toward_target() -> void:
	_comp.target_gravity = Vector2(0.0, -980.0)  # flipped up
	var mag_before: float = _comp.gravity.length()
	var angle_before: float = _comp.gravity.angle()
	# Run several frames — lerp should move toward target, not necessarily converge
	for _i in range(10):
		_comp.update_gravity_lerp(DELTA)
	# After frames, gravity should be closer to target in both angle and magnitude
	var angle_diff_after: float = abs(_comp.gravity.angle() - _comp.target_gravity.angle())
	var angle_diff_before: float = abs(angle_before - _comp.target_gravity.angle())
	assert_float(angle_diff_after).is_less(angle_diff_before)

	var mag_diff_after: float = abs(_comp.gravity.length() - _comp.target_gravity.length())
	var mag_diff_before: float = abs(mag_before - _comp.target_gravity.length())
	assert_float(mag_diff_after).is_less(mag_diff_before)


func test_gravity_lerp_noop_when_already_at_target() -> void:
	_comp.gravity = _comp.target_gravity
	var before := _comp.gravity
	_comp.update_gravity_lerp(DELTA)
	assert_that(_comp.gravity).is_equal(before)