# Contract tests for the GravityAuthority autoload (story GA-001, ADR-0001).
#
# GravityAuthority is the single source of the world gravity vector. Zones
# declare, the authority owns, the player and props consume. These tests cover
# its public contract: the scene-autoload registration, the derived basis, the
# two rejection rules, the ratio invariant, and the refusal to broadcast
# before initialize().
#
# Every case runs headless with no Player and no rendered scene — the
# authority is seeded directly through its public initialize().
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const AUTHORITY_SCENE := "res://src/scripts/autoloads/gravity_authority.tscn"
const AUTHORITY_SCRIPT := "res://src/scripts/autoloads/gravity_authority.gd"

# GDD section 4 "Current values" baseline: g_ascent=2990.72, ratio=0.390625.
const BASELINE_ASCENT := 2990.72
const ASCENT_DESCENT_RATIO := 0.390625

const TOLERANCE := 0.0001
const RATIO_TOLERANCE := 0.000001

var _authority: Node
var _signal_count: int = 0


func before_test() -> void:
	var scene: PackedScene = load(AUTHORITY_SCENE)
	_authority = auto_free(scene.instantiate())
	_signal_count = 0
	_authority.gravity_changed.connect(_on_gravity_changed)


func after_test() -> void:
	_authority = null


func _on_gravity_changed(direction: Vector2, multiplier: float) -> void:
	_signal_count += 1


func _seed() -> void:
	_authority.initialize(BASELINE_ASCENT, ASCENT_DESCENT_RATIO)


# ── AC-1/2/3 — structural contract ───────────────────────────────────────────

func test_autoload_is_registered_as_a_scene_not_a_bare_script() -> void:
	# A .gd path here is the bare-script-autoload defect: @export
	# direction_ease_rate would have no inspector surface (TR-gravity-011).
	var path: String = str(ProjectSettings.get_setting("autoload/GravityAuthority"))
	assert_str(path).contains("gravity_authority.tscn")
	assert_bool(path.ends_with(".gd")).is_false()


func test_authority_script_declares_no_class_name() -> void:
	# A class_name would create a second global identifier for one node.
	# Code lines only — the file discusses the rule in its comments.
	assert_bool(_authority_code().contains("class_name ")).is_false()


func test_authority_guards_use_push_error_never_assert() -> void:
	# Companion check to AC-8: assert() compiles out of release exports, so a
	# guard built on it would vanish in the build that matters — and a test
	# asserting only "no crash" would still pass on that build.
	var code: String = _authority_code()
	assert_bool(code.contains("assert(")).is_false()
	assert_bool(code.contains("push_error(")).is_true()


# Returns the authority source with comment-only lines stripped, so a rule
# quoted in a doc comment cannot satisfy or break a source scan.
func _authority_code() -> String:
	var code: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(AUTHORITY_SCRIPT).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	return "\n".join(code)


func test_public_api_exposes_every_adr_interface_member() -> void:
	var required: Array[String] = [
		"initialize", "reset_to", "set_gravity",
		"register_prop", "unregister_prop",
		"ascent_magnitude", "descent_magnitude",
	]
	for method_name: String in required:
		assert_bool(_authority.has_method(method_name)).is_true()
	assert_bool(_authority.has_signal("gravity_changed")).is_true()


func test_direction_ease_rate_is_an_exported_property_defaulting_to_32() -> void:
	var exported: bool = false
	for property: Dictionary in _authority.get_property_list():
		if property["name"] == "direction_ease_rate":
			exported = (int(property["usage"]) & PROPERTY_USAGE_EDITOR) != 0
	assert_bool(exported).is_true()
	assert_float(_authority.direction_ease_rate).is_equal_approx(32.0, TOLERANCE)


# ── AC-4 — basis derivation at every angle ───────────────────────────────────

func test_reset_to_derives_up_dir_as_negated_gravity_at_each_axis() -> void:
	_seed()
	for direction: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		_authority.reset_to(direction, 1.0)
		_assert_basis_matches(direction)


func test_reset_to_derives_basis_at_a_non_axis_angle() -> void:
	# 45 degrees proves the derivation is angular, not a four-case lookup.
	# GDD AC10 requires the system to hold at any angle.
	_seed()
	_authority.reset_to(Vector2.ONE, 1.0)
	_assert_basis_matches(Vector2.ONE)


func test_right_dir_is_perpendicular_to_up_dir() -> void:
	_seed()
	_authority.reset_to(Vector2(0.3, -0.9), 1.0)
	assert_float(_authority.up_dir.dot(_authority.right_dir)).is_equal_approx(0.0, TOLERANCE)


func _assert_basis_matches(direction: Vector2) -> void:
	var expected_up: Vector2 = -direction.normalized()
	assert_float(_authority.up_dir.x).is_equal_approx(expected_up.x, TOLERANCE)
	assert_float(_authority.up_dir.y).is_equal_approx(expected_up.y, TOLERANCE)
	assert_float(_authority.right_dir.x).is_equal_approx(-expected_up.y, TOLERANCE)
	assert_float(_authority.right_dir.y).is_equal_approx(expected_up.x, TOLERANCE)


# ── AC-5 — zero-length direction is rejected (GDD AC7) ───────────────────────

func test_set_gravity_with_zero_direction_leaves_all_state_untouched() -> void:
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)
	var before: Dictionary = _snapshot()

	_signal_count = 0
	_authority.set_gravity(Vector2.ZERO, 1.0)

	_assert_unchanged(before)
	assert_int(_signal_count).is_equal(0)


func test_set_gravity_with_a_near_zero_direction_is_also_rejected() -> void:
	# is_zero_approx(), not == Vector2.ZERO: an exact comparison lets a
	# degenerate vector through and produces a NaN angle downstream.
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)
	var before: Dictionary = _snapshot()

	_signal_count = 0
	_authority.set_gravity(Vector2(0.000000001, 0.0), 1.0)

	_assert_unchanged(before)
	assert_int(_signal_count).is_equal(0)


func test_reset_to_with_zero_direction_leaves_all_state_untouched() -> void:
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)
	var before: Dictionary = _snapshot()

	_signal_count = 0
	_authority.reset_to(Vector2.ZERO, 1.0)

	_assert_unchanged(before)
	assert_int(_signal_count).is_equal(0)


# ── AC-6 — non-positive multiplier is rejected ───────────────────────────────

func test_set_gravity_rejects_zero_and_negative_multipliers() -> void:
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)

	for multiplier: float in [0.0, -1.0, -0.0001]:
		var before: Dictionary = _snapshot()
		_signal_count = 0
		_authority.set_gravity(Vector2.UP, multiplier)
		_assert_unchanged(before)
		assert_int(_signal_count).is_equal(0)


func test_set_gravity_accepts_the_smallest_positive_multiplier() -> void:
	# The rule is "<= 0", not "implausibly small". A test that only checks 0.0
	# and -1.0 would pass on an over-strict guard.
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)

	_signal_count = 0
	_authority.set_gravity(Vector2.UP, 0.0001)

	assert_int(_signal_count).is_equal(1)
	assert_float(_authority.ascent_magnitude()).is_equal_approx(
		BASELINE_ASCENT * 0.0001, TOLERANCE
	)


# ── AC-7 — ratio invariance (GDD AC4) ────────────────────────────────────────

func test_ascent_descent_ratio_survives_a_long_call_sequence() -> void:
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)

	var multipliers: Array[float] = [0.5, 2.0, 1.0, 0.25, 4.0, 1.0, 0.5, 3.0, 0.1, 1.0]
	var directions: Array[Vector2] = [
		Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.ONE,
		Vector2.DOWN, Vector2(0.5, -0.5), Vector2.UP, Vector2(-0.2, 0.9), Vector2.DOWN,
	]

	for index: int in multipliers.size():
		_authority.set_gravity(directions[index], multipliers[index])
		# Asserted after EVERY call — a ratio that drifts and returns would
		# pass an end-only assertion.
		_assert_ratio_holds()
		# Two rejected calls interleaved: a rejection must not disturb it either.
		if index == 3:
			_authority.set_gravity(Vector2.ZERO, 1.0)
			_assert_ratio_holds()
		if index == 7:
			_authority.set_gravity(Vector2.UP, -2.0)
			_assert_ratio_holds()


func test_ascent_descent_ratio_field_is_never_written_after_initialize() -> void:
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)
	_authority.set_gravity(Vector2.UP, 3.0)
	_authority.reset_to(Vector2.LEFT, 0.25)

	assert_float(_authority.ascent_descent_ratio).is_equal_approx(
		ASCENT_DESCENT_RATIO, RATIO_TOLERANCE
	)


func test_descent_magnitude_matches_the_gdd_baseline() -> void:
	_seed()
	_authority.reset_to(Vector2.DOWN, 1.0)
	# GDD section 4: g_ascent=2990.72, g_descent=7656.25.
	assert_float(_authority.ascent_magnitude()).is_equal_approx(2990.72, 0.01)
	assert_float(_authority.descent_magnitude()).is_equal_approx(7656.25, 0.01)


func _assert_ratio_holds() -> void:
	var descent: float = _authority.descent_magnitude()
	# A zero descent would make the ratio undefined rather than merely wrong.
	assert_bool(descent > 0.0).is_true()
	assert_float(_authority.ascent_magnitude() / descent).is_equal_approx(
		ASCENT_DESCENT_RATIO, RATIO_TOLERANCE
	)


# ── AC-8 — broadcast before initialize is refused (GDD section 5) ────────────

func test_set_gravity_before_initialize_refuses_to_broadcast() -> void:
	# Not seeded. Assert the refusal, not the absence of a crash: the failure
	# this guards is silent — a 1.0 default ratio broadcasting successfully and
	# losing the R4 asymmetry.
	_signal_count = 0
	_authority.set_gravity(Vector2.DOWN, 1.0)

	assert_int(_signal_count).is_equal(0)
	assert_that(_authority.gravity).is_equal(Vector2.ZERO)
	assert_that(_authority.target_gravity).is_equal(Vector2.ZERO)


func test_reset_to_before_initialize_refuses_to_broadcast() -> void:
	_signal_count = 0
	_authority.reset_to(Vector2.UP, 2.0)

	assert_int(_signal_count).is_equal(0)
	assert_that(_authority.gravity).is_equal(Vector2.ZERO)
	assert_that(_authority.target_gravity).is_equal(Vector2.ZERO)


func test_uninitialized_ratio_defaults_to_one_and_never_reaches_a_broadcast() -> void:
	assert_float(_authority.ascent_descent_ratio).is_equal_approx(1.0, TOLERANCE)
	_authority.set_gravity(Vector2.DOWN, 1.0)
	assert_int(_signal_count).is_equal(0)


func test_broadcast_succeeds_once_initialize_has_run() -> void:
	_signal_count = 0
	_authority.set_gravity(Vector2.DOWN, 1.0)
	assert_int(_signal_count).is_equal(0)

	_seed()
	_authority.set_gravity(Vector2.DOWN, 1.0)
	assert_int(_signal_count).is_equal(1)


# ── initialize() input guard ─────────────────────────────────────────────────

func test_initialize_refuses_a_non_positive_ratio() -> void:
	# A zero ratio would make descent_magnitude() a division by zero.
	_authority.initialize(BASELINE_ASCENT, 0.0)
	_signal_count = 0
	_authority.set_gravity(Vector2.DOWN, 1.0)
	assert_int(_signal_count).is_equal(0)


# ── shared helpers ───────────────────────────────────────────────────────────

func _snapshot() -> Dictionary:
	return {
		"gravity": _authority.gravity,
		"target_gravity": _authority.target_gravity,
		"up_dir": _authority.up_dir,
		"right_dir": _authority.right_dir,
		"ascent": _authority.ascent_magnitude(),
		"descent": _authority.descent_magnitude(),
	}


func _assert_unchanged(before: Dictionary) -> void:
	assert_that(_authority.gravity).is_equal(before["gravity"])
	assert_that(_authority.target_gravity).is_equal(before["target_gravity"])
	assert_that(_authority.up_dir).is_equal(before["up_dir"])
	assert_that(_authority.right_dir).is_equal(before["right_dir"])
	assert_float(_authority.ascent_magnitude()).is_equal_approx(float(before["ascent"]), TOLERANCE)
	assert_float(_authority.descent_magnitude()).is_equal_approx(float(before["descent"]), TOLERANCE)
