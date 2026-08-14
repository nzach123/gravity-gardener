class_name PlayerVisualComponent
extends Node

# ---------------------------------------------------------------
# EXPORTS (forwarded from Player facade)
# ---------------------------------------------------------------
@export var squash_stretch_speed: float = 15.0
@export var scale_base: Vector2 = Vector2(2.0, 2.0)
@export var scale_jump: Vector2 = Vector2(1.6, 2.4)
@export var scale_land: Vector2 = Vector2(2.6, 1.4)
@export var scale_run: Vector2 = Vector2(2.2, 1.9)
@export var squash_stretch_enabled: bool = false

# ---------------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------------
var sprite: AnimatedSprite2D

# ---------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------
var land_squash_timer: float = 0.0

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------
## Update sprite rotation, flip, animation, and squash/stretch.
## Call after move_and_slide() in Player._physics_process().
func update(
	delta: float,
	velocity: Vector2,
	is_on_floor: bool,
	right_dir: Vector2,
	up_dir: Vector2,
	input_axis: float,
	gravity: Vector2,
	camera_rotation_enabled: bool
) -> void:
	# Rotate sprite to match current gravity direction.
	var target_rot := gravity.normalized().angle() - (PI * 0.5)
	sprite.rotation = lerp_angle(sprite.rotation, target_rot, 16.0 * delta)

	# Flip sprite to face movement direction.
	if input_axis != 0.0:
		var facing_axis := input_axis
		if not camera_rotation_enabled:
			if not is_zero_approx(right_dir.dot(Vector2.RIGHT)):
				facing_axis = input_axis * sign(right_dir.dot(Vector2.RIGHT))
			else:
				facing_axis = input_axis * -sign(right_dir.y)
		sprite.flip_h = facing_axis < 0.0

	# Squash & stretch (disabled by default).
	if squash_stretch_enabled:
		var target_scale := scale_base
		if land_squash_timer > 0.0:
			target_scale = scale_land
		elif not is_on_floor:
			target_scale = scale_jump
		elif absf(velocity.dot(right_dir)) > 400.0 * 0.8:
			target_scale = scale_run

		sprite.scale = sprite.scale.lerp(target_scale, squash_stretch_speed * delta)

	# Animations.
	if not is_on_floor:
		sprite.play("Falling" if velocity.dot(-up_dir) > 0 else "Jump")
	elif is_zero_approx(velocity.dot(right_dir)):
		sprite.play("Idle")
	else:
		sprite.play("Run")

	# Decay land squash timer.
	if land_squash_timer > 0.0:
		land_squash_timer -= delta

# ---------------------------------------------------------------
# SIGNAL HANDLERS (connected by Player facade)
# ---------------------------------------------------------------
func _on_jumped() -> void:
	land_squash_timer = 0.0

func _on_landed() -> void:
	land_squash_timer = 0.15

func _on_wall_jumped() -> void:
	pass

func _on_watering_started() -> void:
	pass

func _on_watering_stopped() -> void:
	pass
