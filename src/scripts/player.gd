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

## Screen-right axis for the current gravity orientation. Proxied from
## `GravityAuthority` so external readers keep one call site (GDD R1).
var right_dir: Vector2:
	get: return GravityAuthority.right_dir

## Screen-up axis for the current gravity orientation.
var up_dir: Vector2:
	get: return GravityAuthority.up_dir

# ---------------------------------------------------------------
# READY
# ---------------------------------------------------------------
func _ready() -> void:
	# Capture actual sprite scale before forwarding exports
	scale_base = sprite.scale
	_forward_exports()
	gravity_component.initialize(max_speed)
	# Seed the authority with the jump-derived baseline before anything can
	# broadcast. Godot readies children before parents, so this lands ahead of
	# LevelRoot._ready()'s reset_to() (ADR-0001 part 7).
	GravityAuthority.initialize(
		gravity_component.baseline_ascent_magnitude(),
		gravity_component.ascent_descent_ratio()
	)
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

	# 2. Adopt the authority's basis. The turn itself is eased by
	#    GravityAuthority._physics_process(); nothing is derived locally.
	up_direction = GravityAuthority.up_dir

	# 4. Apply ascent/descent gravity to velocity
	velocity = gravity_component.apply_gravity(delta, velocity, is_on_floor())

	# 5. Wall jump (only if enabled)
	if wall_jump_component.enable_wall_jump:
		velocity = wall_jump_component.try(
			delta, velocity, is_on_floor(), is_on_wall(),
			GravityAuthority.up_dir,
			func(): return get_wall_normal()
		)

	# 6. Jump (coyote, buffer, release, landing)
	velocity = jump_component.update(
		delta, velocity, is_on_floor(),
		GravityAuthority.up_dir, GravityAuthority.right_dir
	)

	# 7. Lateral movement
	var input_axis: float = Input.get_axis("move_left", "move_right")
	velocity = movement_component.apply(
		delta, velocity, is_on_floor(),
		GravityAuthority.right_dir, GravityAuthority.up_dir,
		input_axis, camera_rotation_enabled
	)

	# 8. Resolve collisions
	move_and_slide()

	# 9. Visuals
	visual_component.update(
		delta, velocity, is_on_floor(),
		GravityAuthority.right_dir, GravityAuthority.up_dir,
		input_axis, GravityAuthority.gravity, camera_rotation_enabled
	)

# ---------------------------------------------------------------
# EXTERNAL API
# ---------------------------------------------------------------
## Called when the player reaches the level goal.
func win_level() -> void:
	pass


# ---------------------------------------------------------------
# LEVEL STATE INJECTION (ADR-0002 part 3)
# ---------------------------------------------------------------
# Injected by LevelRoot._ready() at step (c). _ready() runs bottom-up, so this is
# still null during THIS node's _ready() — never read it there
# (`state_access_before_bind` is forbidden).
var _level_state: LevelState = null
var _bound: bool = false


## Receives this level's [LevelState] from `LevelRoot._ready()`. Called exactly
## once per level, after every child is ready.
func bind(level_state: LevelState) -> void:
	_level_state = level_state
	_bound = true


## Whether the player is currently carrying a bucket, read from the injected
## [LevelState].
##
## There is no caller yet by design. The reader that arrives later is ADR-0009's
## `PlayerWateringComponent`, which owns pickup, pour and release; this accessor
## exists so that component reads level state through its host rather than
## reaching for a global.
##
## Refuses to operate before [method bind] has run: `push_error()` LOGS but does
## not pause execution, so the early `return` is what actually prevents the null
## dereference. `assert()` is not used — it compiles out of release exports and
## this guard would silently vanish from the shipped build (ADR-0002, A2-02).
func is_carrying_bucket() -> bool:
	if not _bound:
		push_error("Player: is_carrying_bucket() called before bind()")
		return false
	return _level_state.carrying_bucket
	
