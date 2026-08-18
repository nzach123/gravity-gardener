# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Scene autoload (script attached to GravityAuthority.tscn), never a bare script
# autoload — a bare script autoload gives direction_ease_rate no inspector surface
# (ADR-0001). No class_name — reached only through the autoload singleton name; a
# class_name would create two competing global identifiers.
#
# Sole writer of gravity. Read via GravityAuthority.gravity / .up_dir / .right_dir,
# or by connecting to gravity_changed(direction, multiplier).
extends Node

signal gravity_changed(direction: Vector2, multiplier: float)

@export var direction_ease_rate: float = 32.0

var gravity: Vector2 = Vector2.DOWN
var up_dir: Vector2 = Vector2.UP
var right_dir: Vector2 = Vector2.RIGHT
var jump_velocity: float = 0.0  # fixed after initialize() — never recomputed (gravity.md R5)

var ascent_mag: float:
	get: return _gravity_ascent_mag
var descent_mag: float:
	get: return _gravity_descent_mag

var _current_angle: float = 0.0
var _target_angle: float = 0.0
var _gravity_ascent_mag: float = 0.0
var _gravity_descent_mag: float = 0.0
var _baseline_ascent_mag: float = 0.0
var _ascent_descent_ratio: float = 1.0
var _initialized: bool = false


func _ready() -> void:
	process_physics_priority = FramePriority.GRAVITY_AUTHORITY


## Derives gravity magnitudes and jump velocity from jump params + max_speed
## (gravity.md §4). Called once from Player._ready() — jump constants stay
## @export on Player, never in a tuning resource (ADR-0001 part 7, ADR-0006 D6.7).
func initialize(max_speed: float, jump_height: float, jump_distance_to_peak: float, jump_distance_to_land: float) -> void:
	var t_up: float = jump_distance_to_peak / max_speed
	var t_down: float = jump_distance_to_land / max_speed

	_gravity_ascent_mag = (2.0 * jump_height) / (t_up * t_up)
	_gravity_descent_mag = (2.0 * jump_height) / (t_down * t_down)
	jump_velocity = (2.0 * jump_height) / t_up
	_ascent_descent_ratio = _gravity_ascent_mag / _gravity_descent_mag
	_baseline_ascent_mag = _gravity_ascent_mag

	_current_angle = Vector2.DOWN.angle()
	_target_angle = _current_angle
	gravity = Vector2.RIGHT.rotated(_current_angle) * _gravity_ascent_mag
	up_dir = -gravity.normalized()
	right_dir = Vector2(-up_dir.y, up_dir.x)
	_initialized = true


## Sets gravity to a level's declared default WITHOUT easing, and writes the space
## parameters synchronously — otherwise a reload_current_scene() would inherit the
## previous level's stale space gravity. Called from LevelRoot._ready().
func reset_to(direction: Vector2, multiplier: float) -> void:
	if direction.is_zero_approx() or multiplier <= 0.0:
		push_error("GravityAuthority.reset_to: invalid direction or multiplier")
		return
	_gravity_ascent_mag = _baseline_ascent_mag * multiplier
	_gravity_descent_mag = _gravity_ascent_mag / _ascent_descent_ratio
	_current_angle = direction.normalized().angle()
	_target_angle = _current_angle
	gravity = Vector2.RIGHT.rotated(_current_angle) * _gravity_ascent_mag
	up_dir = -gravity.normalized()
	right_dir = Vector2(-up_dir.y, up_dir.x)
	_write_space_gravity()
	gravity_changed.emit(direction.normalized(), multiplier)


## Called by GravityZone when the player enters it. Never call before initialize()
## — the asymmetry ratio would still be 1.0 (gravity.md §5 edge case).
func set_gravity(direction: Vector2, multiplier: float) -> void:
	if direction.is_zero_approx() or multiplier <= 0.0:
		return
	_gravity_ascent_mag = _baseline_ascent_mag * multiplier
	_gravity_descent_mag = _gravity_ascent_mag / _ascent_descent_ratio
	_target_angle = direction.normalized().angle()
	gravity_changed.emit(direction.normalized(), multiplier)


## Direction eases via lerp_angle; strength already snapped in set_gravity() above
## (gravity.md R3). Must run in _physics_process, never _process, every frame while
## gravity != target_gravity (ADR-0001 part 4a).
func _physics_process(delta: float) -> void:
	if is_equal_approx(_current_angle, _target_angle):
		return
	_current_angle = lerp_angle(_current_angle, _target_angle, clampf(direction_ease_rate * delta, 0.0, 1.0))
	gravity = Vector2.RIGHT.rotated(_current_angle) * _gravity_ascent_mag
	up_dir = -gravity.normalized()
	right_dir = Vector2(-up_dir.y, up_dir.x)
	_write_space_gravity()


func _write_space_gravity() -> void:
	var space: RID = get_tree().root.world_2d.space
	PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, gravity.normalized())
	PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY, gravity.length())
