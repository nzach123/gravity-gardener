# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Near-stateless (ADR-0007 D7.2): retains only initialize(), jump_velocity
# (read-only after init — caching it is legitimate since it is fixed forever, unlike
# a gravity-derived value), and apply_gravity() as a pure function taking
# gravity/ascent/descent as parameters. Does NOT derive its own up_dir/right_dir —
# every consumer reads GravityAuthority directly.
class_name PlayerGravityComponent
extends Node

var jump_velocity: float = 0.0  # fixed after initialize() — never recomputed (gravity.md R5)


func initialize(max_speed: float, jump_height: float, jump_distance_to_peak: float, jump_distance_to_land: float) -> void:
	GravityAuthority.initialize(max_speed, jump_height, jump_distance_to_peak, jump_distance_to_land)
	jump_velocity = GravityAuthority.jump_velocity


func apply_gravity(delta: float, velocity: Vector2, is_on_floor: bool, gravity: Vector2, ascent_mag: float, descent_mag: float) -> Vector2:
	if is_on_floor:
		return velocity
	var vel_up: float = velocity.dot(-gravity.normalized())
	var grav_mag: float = ascent_mag if vel_up > 0.0 else descent_mag
	return velocity + gravity.normalized() * grav_mag * delta
