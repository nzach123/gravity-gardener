# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Cosmetic-only work stays in _process-equivalent (called from Player's single
# physics slot per ADR-0005 D5.5) — no rule-bearing quantity lives here.
class_name PlayerVisualComponent
extends Node

## Placeholder-quality: a plain Polygon2D triangle stands in for a sprite — no
## animation frames are authored for this slice (art quality is explicitly out of
## scope; only the rotation/facing LOGIC below is ADR-relevant).
var sprite: Node2D


## Runs unconditionally as step 8 of Player._physics_process, watering or not
## (control-manifest: watering_lockout_skips_visuals is forbidden).
func update(
	delta: float,
	velocity: Vector2,
	is_on_floor: bool,
	right_dir: Vector2,
	up_dir: Vector2,
	input_axis: float,
	gravity: Vector2
) -> void:
	var target_rot: float = gravity.normalized().angle() - (PI * 0.5)
	sprite.rotation = lerp_angle(sprite.rotation, target_rot, 16.0 * delta)

	if input_axis != 0.0:
		sprite.scale.x = absf(sprite.scale.x) * (-1.0 if input_axis < 0.0 else 1.0)


func _on_jumped() -> void:
	pass


func _on_landed() -> void:
	pass


func _on_watering_started() -> void:
	pass


func _on_watering_stopped() -> void:
	pass
