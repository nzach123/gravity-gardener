extends CharacterBody2D
class_name Player

# ---------------------------------------------------------------
# MOVEMENT
# ---------------------------------------------------------------
@export_group("Movement")
@export var max_speed: float = 350.0
@export var ground_accel: float = 4500.0
@export var ground_friction: float = 4000.0
@export var air_accel: float = 4000.0

# ---------------------------------------------------------------
# GRAVITY / JUMP  (designer-facing, in pixels — GDC jump math)
# ---------------------------------------------------------------
@export_group("Jump")
@export var jump_height: float = 200.0
@export var jump_distance_to_peak: float = 128.0
@export var jump_distance_to_land: float = 80.0
@export var min_jump_velocity: float = 100.0

@export_group("Timing")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

# ---------------------------------------------------------------
# WALL JUMP
# ---------------------------------------------------------------
@export_group("Wall Jump")
@export var wall_jump_h_force: float = 450.0
@export var wall_jump_v_force: float = 800.0
@export var wall_jump_cooldown: float = 0.15

# ---------------------------------------------------------------
# SQUASH & STRETCH
# ---------------------------------------------------------------
@export_group("Squash and Stretch")
@export var squash_stretch_speed: float = 15.0
@export var scale_base: Vector2 = Vector2(2.0, 2.0)
@export var scale_jump: Vector2 = Vector2(1.6, 2.4)
@export var scale_land: Vector2 = Vector2(2.6, 1.4)
@export var scale_run: Vector2 = Vector2(2.2, 1.9)

# ---------------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------------
@onready var sprite: AnimatedSprite2D = $PlayerAnimatedSprite2D
@onready var col_shape: CollisionShape2D = $PlayerArea2D/PlayerCollisionShape2D

@onready var movement_component: PlayerMovementComponent = $PlayerMovementComponent
@onready var gravity_component: PlayerGravityComponent = $PlayerGravityComponent
@onready var jump_component: PlayerJumpComponent = $PlayerJumpComponent
@onready var wall_jump_component: PlayerWallJumpComponent = $PlayerWallJumpComponent
@onready var watering_component: PlayerWateringComponent = $PlayerWateringComponent
@onready var visual_component: PlayerVisualComponent = $PlayerVisualComponent

# ---------------------------------------------------------------
# PROXY PROPERTIES (preserve external contract)
# ---------------------------------------------------------------
var camera_rotation_enabled: bool = true
var player_died: bool = false

var is_watering: bool:
	get: return watering_component.is_watering
	set(v): watering_component.is_watering = v

var current_plant: Plant:
	get: return watering_component.current_plant
	set(v): watering_component.current_plant = v

var target_gravity: Vector2:
	get: return gravity_component.target_gravity

var right_dir: Vector2:
	get: return gravity_component.right_dir

var up_dir: Vector2:
	get: return gravity_component.up_dir

# ---------------------------------------------------------------
# READY
# ---------------------------------------------------------------
func _ready() -> void:
	# Capture actual sprite scale before forwarding exports
	scale_base = sprite.scale
	_forward_exports()
	gravity_component.initialize(max_speed)
	jump_component.set_jump_velocity(gravity_component.jump_velocity)
	visual_component.sprite = sprite

	# Wire component signals
	jump_component.jumped.connect(visual_component._on_jumped)
	jump_component.landed.connect(visual_component._on_landed)
	wall_jump_component.wall_jumped.connect(visual_component._on_wall_jumped)
	watering_component.watering_started.connect(visual_component._on_watering_started)
	watering_component.watering_stopped.connect(visual_component._on_watering_stopped)

# ---------------------------------------------------------------
# EXPORT FORWARDING
# ---------------------------------------------------------------
func _forward_exports() -> void:
	movement_component.max_speed = max_speed
	movement_component.ground_accel = ground_accel
	movement_component.ground_friction = ground_friction
	movement_component.air_accel = air_accel

	gravity_component.jump_height = jump_height
	gravity_component.jump_distance_to_peak = jump_distance_to_peak
	gravity_component.jump_distance_to_land = jump_distance_to_land

	jump_component.min_jump_velocity = min_jump_velocity
	jump_component.coyote_time = coyote_time
	jump_component.jump_buffer_time = jump_buffer_time

	wall_jump_component.wall_jump_h_force = wall_jump_h_force
	wall_jump_component.wall_jump_v_force = wall_jump_v_force
	wall_jump_component.wall_jump_cooldown = wall_jump_cooldown

	visual_component.squash_stretch_speed = squash_stretch_speed
	visual_component.scale_base = scale_base
	visual_component.scale_jump = scale_jump
	visual_component.scale_land = scale_land
	visual_component.scale_run = scale_run

# ---------------------------------------------------------------
# PHYSICS LOOP
# ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	# 1. Watering lockout
	if watering_component.is_watering:
		velocity = Vector2.ZERO
		return

	# 2. Derive directions from current gravity
	gravity_component.update_derived_dirs()
	up_direction = -gravity_component.gravity.normalized()

	# 3. Smooth gravity rotation + magnitude toward target
	gravity_component.update_gravity_lerp(delta)
	up_direction = -gravity_component.gravity.normalized()

	# 4. Apply ascent/descent gravity to velocity
	velocity = gravity_component.apply_gravity(delta, velocity, is_on_floor())

	# 5. Wall jump (only if enabled)
	if wall_jump_component.enable_wall_jump:
		velocity = wall_jump_component.try(
			delta, velocity, is_on_floor(), is_on_wall(),
			gravity_component.up_dir,
			func(): return get_wall_normal()
		)

	# 6. Jump (coyote, buffer, release, landing)
	velocity = jump_component.update(
		delta, velocity, is_on_floor(),
		gravity_component.up_dir, gravity_component.right_dir
	)

	# 7. Lateral movement
	var input_axis: float = Input.get_axis("move_left", "move_right")
	velocity = movement_component.apply(
		delta, velocity, is_on_floor(),
		gravity_component.right_dir, gravity_component.up_dir,
		input_axis, camera_rotation_enabled
	)

	# 8. Resolve collisions
	move_and_slide()

	# 9. Visuals
	visual_component.update(
		delta, velocity, is_on_floor(),
		gravity_component.right_dir, gravity_component.up_dir,
		input_axis, gravity_component.gravity, camera_rotation_enabled
	)

# ---------------------------------------------------------------
# EXTERNAL API
# ---------------------------------------------------------------
func set_gravity(new_vector: Vector2) -> void:
	gravity_component.set_gravity(new_vector, max_speed)
	jump_component.set_jump_velocity(gravity_component.jump_velocity)

func win_level() -> void:
	pass
	
