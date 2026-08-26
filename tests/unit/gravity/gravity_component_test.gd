# Unit tests for PlayerGravityComponent (post-GA-003).
#
# The component is now a gravity CONSUMER (ADR-0001 part 3). What survives here
# is the half that is genuinely its own: the `initialize()` jump-tuning
# derivation, and the ascent/descent application in `apply_gravity()`.
#
# The four `test_apply_gravity_*` cases are story GA-003's R4 regression bar.
# They are re-pointed at the new call path — the magnitudes now come from the
# `GravityAuthority` autoload — but their expected values are UNCHANGED. A
# changed value here is a retune, not a relocation, and fails GDD AC4.
#
# Everything the component no longer owns moved out rather than vanished:
#   - basis, ease and rejection rules ..... gravity_authority_contract_test.gd
#                                           gravity_authority_easing_test.gd
#   - the seed / ratio / jump-height cases  tests/integration/gravity/
#                                           player_gravity_consumer_test.gd
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
	# apply_gravity() reads the live world vector, so the autoload has to be
	# driven to a known state. Straight down at 1.0x reproduces the exact
	# pre-migration fixture these four cases were written against.
	GravityAuthority.initialize(
		_comp.baseline_ascent_magnitude(), _comp.ascent_descent_ratio()
	)
	GravityAuthority.reset_to(Vector2.DOWN, 1.0)


# ── initialize() ─────────────────────────────────────────────────────────────

func test_initialize_derives_positive_ascent_magnitude() -> void:
	assert_float(_comp.gravity_ascent_mag).is_greater(0.0)


func test_initialize_derives_positive_descent_magnitude() -> void:
	assert_float(_comp.gravity_descent_mag).is_greater(0.0)


func test_initialize_descent_is_stronger_than_ascent() -> void:
	# Descent gravity should be stronger (faster fall than rise)
	assert_float(_comp.gravity_descent_mag).is_greater(_comp.gravity_ascent_mag)


func test_initialize_derives_positive_jump_velocity() -> void:
	assert_float(_comp.jump_velocity).is_greater(0.0)


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
