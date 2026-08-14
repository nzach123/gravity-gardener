# Unit tests for GravityZone direction + multiplier (GDD R7).
#
# GravityZone is an Area2D that emits gravity_changed(direction, multiplier)
# when the player enters. The zone declares only a normalized direction and a
# strength multiplier; absolute magnitude is derived by PlayerGravityComponent
# from its baseline, so zones stay correct when jump tuning changes.
#
# These tests validate the pure math — no scene tree required.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const DIAGONAL_COMPONENT := 0.7071068

var _zone: GravityZone


func before_test() -> void:
	_zone = auto_free(GravityZone.new())


# ── Default values ───────────────────────────────────────────────────────────

func test_gravity_zone_default_direction_is_down() -> void:
	assert_that(_zone.zone_gravity_direction).is_equal(Vector2.DOWN)


func test_gravity_zone_default_multiplier_is_baseline() -> void:
	# 1.0 means "same strength the player's jump was tuned against" (GDD R7).
	assert_that(_zone.zone_gravity_multiplier).is_equal(1.0)


func test_gravity_zone_default_priority_is_zero() -> void:
	assert_that(_zone.zone_priority).is_equal(0)


# ── get_zone_gravity_direction() ──────────────────────────────────────────────────

func test_get_zone_gravity_direction_default_returns_down() -> void:
	assert_that(_zone.get_zone_gravity_direction()).is_equal(Vector2.DOWN)


func test_get_zone_gravity_direction_up_returns_negative_y() -> void:
	# Arrange
	_zone.zone_gravity_direction = Vector2.UP
	# Act
	var result := _zone.get_zone_gravity_direction()
	# Assert
	assert_that(result).is_equal(Vector2(0.0, -1.0))


func test_get_zone_gravity_direction_right_returns_positive_x() -> void:
	_zone.zone_gravity_direction = Vector2.RIGHT
	assert_that(_zone.get_zone_gravity_direction()).is_equal(Vector2(1.0, 0.0))


func test_get_zone_gravity_direction_left_returns_negative_x() -> void:
	_zone.zone_gravity_direction = Vector2.LEFT
	assert_that(_zone.get_zone_gravity_direction()).is_equal(Vector2(-1.0, 0.0))


func test_get_zone_gravity_direction_unnormalized_input_is_normalized() -> void:
	# Arrange — a long vector must not leak its magnitude into the direction.
	_zone.zone_gravity_direction = Vector2(0.0, 500.0)
	# Act
	var result := _zone.get_zone_gravity_direction()
	# Assert
	assert_that(result).is_equal(Vector2.DOWN)


func test_get_zone_gravity_direction_diagonal_is_normalized() -> void:
	_zone.zone_gravity_direction = Vector2(1.0, 1.0)
	var result := _zone.get_zone_gravity_direction()
	assert_float(result.x).is_equal_approx(DIAGONAL_COMPONENT, 0.0001)
	assert_float(result.y).is_equal_approx(DIAGONAL_COMPONENT, 0.0001)


func test_get_zone_gravity_direction_zero_input_returns_zero() -> void:
	# Edge case: Vector2.ZERO.normalized() = Vector2.ZERO in Godot.
	# PlayerGravityComponent.set_gravity() rejects this (GDD edge case table).
	_zone.zone_gravity_direction = Vector2.ZERO
	assert_that(_zone.get_zone_gravity_direction()).is_equal(Vector2.ZERO)


func test_get_zone_gravity_direction_ignores_multiplier() -> void:
	# Regression: multiplier must not scale the direction vector — that
	# conflation is what the old absolute-strength API got wrong (GDD R7).
	_zone.zone_gravity_multiplier = 2.0
	assert_that(_zone.get_zone_gravity_direction()).is_equal(Vector2.DOWN)


# ── Signal emission ──────────────────────────────────────────────────────────

func test_gravity_changed_emits_direction_and_multiplier_on_player_enter() -> void:
	# Arrange
	assert_bool(_zone.has_signal("gravity_changed")).is_true()
	_zone.zone_gravity_direction = Vector2.UP
	_zone.zone_gravity_multiplier = 0.5
	var player: Player = auto_free(Player.new())
	# GDScript lambdas capture by value — use Array wrappers for mutability
	var got_dir: Array[Vector2] = [Vector2.INF]
	var got_mult: Array[float] = [-1.0]

	# Act
	_zone.gravity_changed.connect(
		func(d: Vector2, m: float) -> void:
			got_dir[0] = d
			got_mult[0] = m
	)
	_zone._on_body_entered(player)

	# Assert
	assert_that(got_dir[0]).is_equal(Vector2(0.0, -1.0))
	assert_float(got_mult[0]).is_equal(0.5)


func test_gravity_changed_ignores_non_player_bodies() -> void:
	# Arrange
	var not_a_player: Node2D = auto_free(Node2D.new())
	var received: Array[bool] = [false]

	# Act
	_zone.gravity_changed.connect(
		func(_d: Vector2, _m: float) -> void: received[0] = true
	)
	_zone._on_body_entered(not_a_player)

	# Assert
	assert_bool(received[0]).is_false()
