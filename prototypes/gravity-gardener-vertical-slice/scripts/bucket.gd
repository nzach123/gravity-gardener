# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# extends Area2D, not Node (ADR-0009 TR-watering-016). collision_layer = 0,
# collision_mask = PLAYER (ADR-0004), set on the .tscn. Static world object — does
# not respond to gravity changes (watering-system.md §5).
class_name Bucket
extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.watering_component.pickup_bucket(self)


## Called by PlayerWateringComponent.pickup_bucket() — fired from within
## PhysicsServer2D::flush_queries(), so the monitoring mutation must be deferred
## (ADR-0009 D4).
func on_picked_up() -> void:
	set_deferred("monitoring", false)


## Called by PlayerWateringComponent on pour completion (watering-system.md R7).
func consume(player_body: Node2D) -> void:
	# up_dir/right_dir captured into LOCAL variables at the call site, before any
	# deferral — a mid-flight gravity flip must NOT re-aim the arc (ADR-0012 D12.2).
	var up_dir: Vector2 = GravityAuthority.up_dir
	var right_dir: Vector2 = GravityAuthority.right_dir
	throw_spent(up_dir, right_dir)


## Creates its own tween, plays the arc, and frees on completion. consume() and
## PlayerWateringComponent.update_pour() stay unchanged/frozen by this method
## existing (ADR-0012 D12.1).
func throw_spent(up_dir: Vector2, right_dir: Vector2) -> void:
	# monitorable = false SYNCHRONOUSLY — a different physics window than
	# on_picked_up()'s deferred write (ADR-0012 D12.4).
	monitorable = false
	# Detach via top_level + re-assign global_position, never reparenting, which
	# would mutate the tree inside a physics callback (ADR-0012 D12.3).
	top_level = true

	var spread_rad: float = deg_to_rad(Tuning.WATERING.throw_angle_spread)
	# Randomness confined to the throw angle only (ADR-0012 D12.7) — no test may
	# assert on jug position, only on free-time and node count.
	var theta: float = randf_range(-spread_rad, spread_rad)
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var throw_dir: Vector2 = right_dir.rotated(theta) * side

	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + throw_dir * 80.0
	var arc_height: float = Tuning.WATERING.throw_arc_height
	var duration: float = Tuning.WATERING.throw_duration

	var tween: Tween = create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var lateral: Vector2 = start_pos.lerp(end_pos, t)
			# sin(), never tan() — tan has a singularity at 90 deg, the top of the
			# GDD's legal throw_angle_spread range (ADR-0012 D12.6).
			var height: float = sin(t * PI) * arc_height
			global_position = lateral - up_dir * height,
		0.0, 1.0, duration
	)
	tween.finished.connect(queue_free)
