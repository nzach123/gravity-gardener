# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# No wall jump — it has no GDD and is not part of the MVP Definition's four core
# systems, so it is out of this slice's scope by construction.
#
# Player._physics_process reads GravityAuthority.gravity/.up_dir/.right_dir fresh
# every frame into locals and threads them as parameters (ADR-0007 D7.1) — no
# component stores a gravity-derived value in a field that survives past the
# callback. set_gravity() does not exist on Player — GravityZone reports to
# GravityAuthority directly (ADR-0001 zone_targets_player_directly is forbidden).
extends CharacterBody2D
class_name Player

@export_group("Movement")
@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0
@export var ground_friction: float = 4000.0
@export var air_accel: float = 4000.0

@export_group("Jump")
@export var jump_height: float = 200.0
@export var jump_distance_to_peak: float = 128.0
@export var jump_distance_to_land: float = 80.0
@export var min_jump_velocity: float = 100.0

@export_group("Timing")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

@onready var sprite: Polygon2D = $PlayerPolygon2D
@onready var hand_marker: Marker2D = $HandMarker

@onready var movement_component: PlayerMovementComponent = $PlayerMovementComponent
@onready var gravity_component: PlayerGravityComponent = $PlayerGravityComponent
@onready var jump_component: PlayerJumpComponent = $PlayerJumpComponent
@onready var watering_component: PlayerWateringComponent = $PlayerWateringComponent
@onready var visual_component: PlayerVisualComponent = $PlayerVisualComponent

var player_died: bool = false


func _ready() -> void:
	process_physics_priority = FramePriority.PLAYER
	_forward_exports()
	gravity_component.initialize(max_speed, jump_height, jump_distance_to_peak, jump_distance_to_land)
	jump_component.set_jump_velocity(gravity_component.jump_velocity)
	visual_component.sprite = sprite
	watering_component.player_body = self

	jump_component.jumped.connect(visual_component._on_jumped)
	jump_component.landed.connect(visual_component._on_landed)
	watering_component.watering_started.connect(visual_component._on_watering_started)
	watering_component.watering_stopped.connect(visual_component._on_watering_stopped)


func _forward_exports() -> void:
	movement_component.max_speed = max_speed
	movement_component.ground_accel = ground_accel
	movement_component.ground_friction = ground_friction
	movement_component.air_accel = air_accel
	jump_component.min_jump_velocity = min_jump_velocity
	jump_component.coyote_time = coyote_time
	jump_component.jump_buffer_time = jump_buffer_time


func _physics_process(delta: float) -> void:
	# 1. up_direction sync — FIRST statement, before any is_on_floor()/is_on_wall()/
	#    move_and_slide() call in this callback (ADR-0007 Player.up_direction_sync)
	up_direction = GravityAuthority.up_dir

	var gravity: Vector2 = GravityAuthority.gravity
	var up_dir: Vector2 = GravityAuthority.up_dir
	var right_dir: Vector2 = GravityAuthority.right_dir
	var ascent_mag: float = GravityAuthority.ascent_mag
	var descent_mag: float = GravityAuthority.descent_mag

	# 2. Watering lockout gate (pour driving happens here regardless of lock state —
	#    update_pour() itself decides whether a pour is active)
	watering_component.update_pour(delta)

	var input_axis: float = 0.0

	if not watering_component.is_watering:
		# 3. Gravity
		velocity = gravity_component.apply_gravity(delta, velocity, is_on_floor(), gravity, ascent_mag, descent_mag)

		# 5. Jump (step 4, wall jump, omitted — out of scope)
		velocity = jump_component.update(delta, velocity, is_on_floor(), up_dir, right_dir)

		# 6. Movement — carry penalty applies while holding a bucket (watering-system.md R2)
		input_axis = Input.get_axis("move_left", "move_right")
		var effective_speed: float = max_speed
		if watering_component.is_carrying():
			effective_speed = max_speed * Tuning.WATERING.carry_speed_multiplier
		velocity = movement_component.apply(delta, velocity, is_on_floor(), right_dir, up_dir, input_axis, effective_speed)
	else:
		velocity = Vector2.ZERO

	# 7. Resolve collisions
	move_and_slide()

	# 8. Visuals — runs UNCONDITIONALLY, watering or not
	visual_component.update(delta, velocity, is_on_floor(), right_dir, up_dir, input_axis, gravity)


func _process(_delta: float) -> void:
	# Cosmetic-only: carried bucket follows the hand marker (diegetic carry read,
	# watering-system.md §6 — no HUD carry indicator).
	if watering_component.is_carrying():
		watering_component.held_bucket.global_position = hand_marker.global_position
